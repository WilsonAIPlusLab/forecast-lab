<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, ym } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { fitETS, filter, conformalQ, type Spec } from './models';

  // Split conformal, step by step: calibration errors → quantile → band → check on the next 12 months.
  const spec: Spec = { m: 12, trend: true, season: true };
  let base: { dates: Date[]; y: number[]; f: number[]; start: number } | null = $state.raw(null);
  let n = $state(36);
  let level = $state(80);
  let endIdx = $state(0);          // index of the last calibration month
  let minE = $state(0), maxE = $state(0);
  let elH: HTMLDivElement, elB: HTMLDivElement;

  onMount(() => {
    loadSeries('RSXFSN', { start: '2000-01-01' }).then((s) => {
      const y = s.data.map((p) => Math.log(p.value));
      const start = s.data.findIndex((p) => p.date >= new Date('2010-01-01T00:00:00'));
      const fit = fitETS(y.slice(0, start), spec);
      const { fitted } = filter(y, spec, fit.par);
      base = { dates: s.data.map((p) => p.date), y, f: fitted, start };
      minE = start + 60 - 1; maxE = y.length - 13;
      endIdx = s.data.findIndex((p) => p.date.getFullYear() === 2018 && p.date.getMonth() === 11);
    });
    return watchLayout(elH, draw);
  });

  const res = $derived.by(() => {
    if (!base || !endIdx) return null;
    const { y, f, dates } = base;
    const a = 1 - level / 100;
    const cal = Array.from({ length: n }, (_, j) => endIdx - n + 1 + j).map((t) => ({ date: dates[t], s: 100 * Math.abs(y[t] - f[t]) }));
    const q = conformalQ(cal.map((c) => c.s), a);
    const k = Math.ceil((n + 1) * (1 - a));
    const test = Array.from({ length: 12 }, (_, j) => endIdx + 1 + j).map((t) => {
      const fc = Math.exp(f[t]) / 1000, act = Math.exp(y[t]) / 1000;
      return { date: dates[t], fc, act, lo: fc * Math.exp(-q / 100), hi: fc * Math.exp(q / 100), inside: Math.abs(y[t] - f[t]) * 100 <= q };
    });
    return { cal, q, k, test, inside: test.filter((t) => t.inside).length };
  });

  function draw() {
    if (!elH || !res) return;
    const W = elH.clientWidth;
    const finite = Number.isFinite(res.q);
    elH.replaceChildren(Plot.plot({
      width: W, height: 200, marginLeft: 40, marginRight: 16, marginTop: 26, style: plotStyle(),
      x: { label: 'Calibration miss, |error| (≈ % of forecast) →', domain: [0, Math.max(...res.cal.map((c) => c.s), finite ? res.q : 0) * 1.08] },
      y: { grid: true, label: '↑ Months', ticks: 4 },
      marks: [
        Plot.rectY(res.cal, Plot.binX({ y: 'count' }, { x: 's', thresholds: 20, fill: (d: any) => (d.s <= res.q ? 'in' : 'out'), insetLeft: 0.5, insetRight: 0.5 } as any)),
        Plot.ruleY([0], { stroke: C.borderStrong }),
        finite ? Plot.ruleX([res.q], { stroke: C.forecast, strokeWidth: 3 }) : null,
        finite ? Plot.text([res.q], { x: (d: any) => d, frameAnchor: 'top', dy: -16, dx: 6, textAnchor: 'start', text: () => `q = ${res.q.toFixed(2)}% (the ${res.k}th smallest of ${n})`, fill: C.text, fontSize: 12, fontWeight: 600, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' } as any) : null,
      ].filter(Boolean) as any,
      color: { domain: ['in', 'out'], range: [C.s[0], C.muted] },
    }));
    elB.replaceChildren(Plot.plot({
      width: W, height: 220, marginLeft: 50, marginRight: 16, marginTop: 10, style: plotStyle(),
      x: { label: null }, y: { grid: true, label: '↑ Retail sales, next 12 months ($ billions)' },
      marks: [
        finite ? Plot.areaY(res.test, { x: 'date', y1: 'lo', y2: 'hi', fill: C.forecast, fillOpacity: 0.22, curve: 'step' }) : null,
        Plot.lineY(res.test, { x: 'date', y: 'fc', stroke: C.forecast, strokeWidth: 2, curve: 'step' }),
        Plot.dot(res.test, { x: 'date', y: 'act', symbol: (d: any) => (d.inside ? 'circle' : 'times'), r: (d: any) => (d.inside ? 4 : 5.5), fill: (d: any) => (d.inside ? C.actual : 'none'), stroke: (d: any) => (d.inside ? C.surface : C.danger), strokeWidth: (d: any) => (d.inside ? 1 : 2.4) }),
        Plot.tip(res.test, Plot.pointerX({ x: 'date', y: 'act', title: (r: any) => `${ym(r.date)}\nActual: $${r.act.toFixed(1)} bn\nForecast: $${r.fc.toFixed(1)} bn\nBand: $${r.lo.toFixed(1)}–${r.hi.toFixed(1)} bn\n${r.inside ? 'Inside' : 'MISS'}` })),
      ].filter(Boolean) as any,
    }));
  }
  $effect(() => { res; draw(); });
</script>

<Explorable title="Split conformal: past misses set the width of future bands"
  caption="Each month of retail sales (RSXFSN, NSA) gets a one-month-ahead forecast from an exponential smoothing model fitted once on 2000–2009. <b>Top:</b> the sizes of the forecast misses in the calibration window. The cutoff q is the ⌈(n+1)(1−α)⌉-th smallest miss. <b>Bottom:</b> the next 12 months, each with the band forecast × (1 ± q) (applied on the log scale). Gold circles landed inside; red crosses are misses. Move the calibration window across 2020 and watch what breaks.">
  {#snippet controls()}
    {#if base}
      <label class="sl">Calibration ends <input type="range" min={minE} max={maxE} bind:value={endIdx} aria-valuetext={ym(base.dates[endIdx])} /> <b>{ym(base.dates[endIdx])}</b></label>
    {/if}
    <label class="sl">Calibration size <input type="range" min="12" max="60" step="1" bind:value={n} aria-valuetext={`${n} months`} /> <b>{n} mo</b></label>
    <label class="sl">Level <input type="range" min="50" max="95" step="5" bind:value={level} aria-valuetext={`${level} percent`} /> <b>{level}%</b></label>
  {/snippet}
  {#snippet aside()}
    {#if res}
      <div class="ro" aria-live="polite">
        <div class="stat"><span class="stat-v">{res.inside} of 12</span><span class="stat-l">next months inside the {level}% band</span></div>
        {#if Number.isFinite(res.q)}
          <p>Band: forecast ± <b>{res.q.toFixed(2)}%</b>.</p>
        {:else}
          <p class="warn">With n = {n}, the {level}% rule asks for the {res.k}th smallest of {n} misses, which does not exist: the band is infinite. Small calibration sets cannot support high levels.</p>
        {/if}
        <p class="hint">The guarantee is about the long run: over many calibrate-then-test repetitions, the band covers at least {level}% of the time, if past and future misses are exchangeable. Any single year can miss more.</p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={elH} role="img" aria-label="Histogram of calibration errors with the conformal cutoff"></div>
  <div bind:this={elB} role="img" aria-label="Conformal band and actual values for the next twelve months"></div>
</Explorable>

<style>
  .ro { font-size: .84rem; color: var(--text-2); display: grid; gap: .55rem; }
  .ro p { margin: 0; }
  .ro b { color: var(--text); font-variant-numeric: tabular-nums; }
  .warn { color: var(--danger); }
  .hint { color: var(--muted); font-size: .78rem; }
</style>
