<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, css, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { forecastSets, recessionSpans, sigmoid, confusion, mon, pct, type Row } from './model';

  // Probability through time, dated at the month it is about, with NBER shading and a threshold.
  type Model = 'full' | 'rt';
  let model: Model = $state('rt');
  let th = $state(0.3);
  let view: 'all' | 'recent' = $state('all');
  let el: HTMLDivElement;
  let rows: Row[] = $state.raw([]);
  let coefs: Record<Model, { a: number; b: number }> = $state.raw({ full: { a: 0, b: 0 }, rt: { a: 0, b: 0 } });
  let spans: { a: Date; b: Date }[] = $state.raw([]);
  let hover: { r: Row; p: number } | null = $state(null);

  onMount(() => {
    let stop = () => {};
    Promise.all([forecastSets(), recessionSpans()]).then(([f, s]) => { spans = s; coefs = { full: f.full, rt: f.rt }; rows = f.rows; stop = watchLayout(el, draw); });
    return () => stop();
  });

  const series = $derived(rows.map((r) => ({ r, p: sigmoid(coefs[model].a + coefs[model].b * r.spread) })));
  const visible = $derived(series.filter((d) => view === 'all' || d.r.target.getFullYear() >= 2000));
  const scored = $derived(visible.filter((d) => d.r.ahead !== null && (model === 'full' || d.r.date.getFullYear() >= 2000)));
  const cm = $derived(scored.length ? confusion(scored.map((d) => d.p), scored.map((d) => d.r.ahead!), th) : null);
  const last = $derived(series.length ? series[series.length - 1] : null);
  const shown = $derived(hover ?? last);

  function draw() {
    if (!el || !series.length) return;
    const W = el.clientWidth;
    const x0 = view === 'all' ? new Date(1960, 0, 1) : new Date(2000, 0, 1);
    const x1 = new Date(2027, 11, 1);
    const sp = spans.filter((s) => +s.b >= +x0);
    const sig = visible.filter((d) => d.p >= th).map((d) => ({ ...d, kind: d.r.ahead === null ? 'pending' : d.r.ahead ? 'hit' : 'false' }));
    const colK: Record<string, string> = { hit: C.good, false: C.danger, pending: C.muted };
    const marks: any[] = [
      Plot.rectX(sp, { x1: 'a', x2: 'b', y1: 0, y2: 1, fill: C.muted, fillOpacity: 0.16 }),
      Plot.ruleY([0], { stroke: C.borderStrong }),
      Plot.ruleX(sig, { x: (d: any) => d.r.target, y1: 1.04, y2: 1.1, stroke: (d: any) => colK[d.kind], strokeWidth: Math.max(1.2, W / 900) }),
      Plot.text([{ x: x0, y: 1.07 }], { x: 'x', y: 'y', text: () => 'Signals', dx: -6, textAnchor: 'end', fill: C.muted, fontSize: 12 }),
      Plot.ruleY([th], { stroke: css('--warm'), strokeWidth: 2, strokeDasharray: '4,4' }),
      Plot.text([{ x: x1, y: th }], { x: 'x', y: 'y', text: () => `Threshold ${pct(th)}`, dy: -8, textAnchor: 'end', fill: css('--warm'), fontSize: 12, fontWeight: 650, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
      Plot.lineY(visible, { x: (d: any) => d.r.target, y: 'p', stroke: C.forecast, strokeWidth: 2.2 }),
    ];
    if (model === 'rt') {
      const cut = new Date(2001, 0, 1);
      if (+cut >= +x0) marks.push(Plot.ruleX([cut], { stroke: C.text2, strokeDasharray: '2,3' }), Plot.text([cut], { x: (d: any) => d, frameAnchor: 'top', dy: 28, dx: 5, textAnchor: 'start', text: () => 'Out of sample →', fill: C.text2, fontSize: 12 }));
      if (view === 'all') marks.push(Plot.text([new Date(1961, 0, 1)], { x: (d: any) => d, frameAnchor: 'top', dy: 28, textAnchor: 'start', text: () => 'Fitted on 1959–1999', fill: C.muted, fontSize: 12 }));
    }
    const ann = true;
    if (ann) {
      const peak = visible.filter((d) => d.r.date.getFullYear() >= 2022 && d.r.date.getFullYear() <= 2024).reduce((m, d) => (d.p > m.p ? d : m), { p: -1 } as any);
      if (peak.r) marks.push(Plot.text([peak], { x: (d: any) => d.r.target, y: 'p', text: () => `No recession followed (so far)`, dx: -8, dy: -2, textAnchor: 'end', fill: C.text2, fontSize: 12, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }));
    }
    marks.push(Plot.ruleX(visible, Plot.pointerX({ x: (d: any) => d.r.target, stroke: C.borderStrong })));
    marks.push(Plot.dot(visible, Plot.pointerX({ x: (d: any) => d.r.target, y: 'p', r: 4, fill: C.forecast, stroke: C.surface, strokeWidth: 1.5 })));
    const chart = Plot.plot({
      width: W, height: Math.max(280, Math.min(380, W * 0.45)), marginLeft: 46, marginRight: 12, marginTop: 14, marginBottom: 30,
      style: plotStyle(), x: { domain: [x0, x1], label: null },
      y: { domain: [0, 1.1], ticks: [0, 0.25, 0.5, 0.75, 1], tickFormat: (v: number) => `${Math.round(v * 100)}%`, label: null, grid: true },
      marks,
    }) as any;
    chart.setAttribute('role', 'img');
    chart.setAttribute('aria-label', `Recession probability from the yield-curve logit, dated at the month forecast, with NBER recessions shaded and a ${pct(th)} threshold.`);
    chart.addEventListener('input', () => { hover = chart.value ?? null; });
    el.replaceChildren(chart);
  }
  $effect(() => { visible; th; draw(); });
</script>

<Explorable title="Recession radar: every forecast since 1960, lined up with what happened" caption="The violet line is the model's probability that a given month will be a recession month, plotted at that month (so it was published 12 months earlier). Grey bars are NBER recessions. Ticks along the top mark months where the probability cleared your threshold: <b style='color:var(--good)'>green</b> = a recession did come, <b style='color:var(--danger)'>red</b> = false alarm, grey = not known yet. Start with <b>Real time</b>: a model frozen at the end of 1999 that never saw an outcome after 2000. Hover to read any month.">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Model">
      <button class:on={model === 'rt'} onclick={() => (model = 'rt')}>Real time (frozen in 1999)</button>
      <button class:on={model === 'full'} onclick={() => (model = 'full')}>Fitted on all data</button>
    </div>
    <label class="sl">Threshold <input type="range" min="0.05" max="0.8" step="0.05" bind:value={th} aria-label="Signal threshold" aria-valuetext={`${pct(th)} probability`} /> <b>{pct(th)}</b></label>
    <div class="seg" role="group" aria-label="Time window">
      <button class:on={view === 'all'} onclick={() => (view = 'all')}>1960–2027</button>
      <button class:on={view === 'recent'} onclick={() => (view = 'recent')}>2000–2027</button>
    </div>
  {/snippet}
  {#snippet aside()}
    {#if shown}
      <div class="ms">
        <div class="ro" aria-live="polite">
          <div class="ro-k">{hover ? 'Hovered month' : 'Latest forecast'}</div>
          <div class="ro-v">{pct(shown.p)}</div>
          <div class="ro-l">chance that <b>{mon(shown.r.target)}</b> is a recession month</div>
          <div class="ro-l">Made in {mon(shown.r.date)}, when the spread was <b>{shown.r.spread.toFixed(2)}</b> pct. points</div>
          <div class="ro-l">Outcome: <b>{shown.r.ahead === null ? 'not known yet' : shown.r.ahead ? 'recession' : 'no recession'}</b></div>
        </div>
        {#if cm}
          <div class="cm">
            <div class="cm-t">Scored months{model === 'rt' ? ' (out of sample only)' : ''}{view === 'recent' ? ', 2000 on' : ''}</div>
            <div><span>Recession months flagged</span><b>{cm.tp} of {cm.tp + cm.fn}</b></div>
            <div><span>Calm months flagged (false alarms)</span><b>{cm.fp} of {cm.fp + cm.tn}</b></div>
          </div>
        {/if}
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 280px; }
  .ms { display: grid; gap: 1rem; font-size: .82rem; }
  .ro-k { color: var(--muted); font-size: .76rem; font-weight: 650; }
  .ro-v { font: 650 1.7rem/1.1 var(--font-ui); font-variant-numeric: tabular-nums; color: var(--accent-text); margin: .15rem 0 .3rem; }
  .ro-l { color: var(--text-2); line-height: 1.4; margin-bottom: .2rem; }
  .ro-l b { font-variant-numeric: tabular-nums; color: var(--text); }
  .cm { display: grid; gap: .35rem; border-top: 1px dashed var(--border); padding-top: .7rem; }
  .cm-t { color: var(--muted); font-size: .76rem; font-weight: 650; }
  .cm div:not(.cm-t) { display: flex; justify-content: space-between; gap: .5rem; color: var(--muted); }
  .cm b { color: var(--text); font-variant-numeric: tabular-nums; white-space: nowrap; }
</style>
