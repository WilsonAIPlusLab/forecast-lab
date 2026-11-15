<script lang="ts">
  // Home hero: "Stand at any date. Forecast. Then see what actually happened."
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import { loadSeries, holt, holtWinters, futureDates, ym, mean, type Series } from '../../lib/ts';
  import { C, plotStyle, fmt, watchLayout } from '../../lib/viz/theme';

  const SERIES = [
    { id: 'RSXFSN', label: 'Retail sales', unit: '$ millions', seasonal: true, start: '2010-01-01', origin: '2019-06-01' },
    { id: 'PAYEMS', label: 'Payroll jobs', unit: 'thousand jobs', seasonal: false, start: '2010-01-01', origin: '2019-06-01' },
    { id: 'HOUSTNSA', label: 'Housing starts', unit: 'thousand units', seasonal: true, start: '2010-01-01', origin: '2021-06-01' },
    { id: 'UNRATE', label: 'Unemployment', unit: '%', seasonal: false, start: '2010-01-01', origin: '2019-06-01' },
  ];
  let sel = $state(SERIES[0]);
  let s: Series | null = $state(null);
  let originIdx = $state(0);
  let reveal = $state(false);
  let el: HTMLDivElement;
  const H = 24;

  async function load() {
    s = await loadSeries(sel.id, { start: sel.start });
    const i = s.data.findIndex((p) => p.date >= new Date(sel.origin + 'T00:00:00'));
    originIdx = i > 0 ? i : s.data.length - H - 1;
    reveal = false;
  }

  const model = $derived.by(() => {
    if (!s) return null;
    const train = s.data.slice(0, originIdx + 1);
    const y = train.map((p) => p.value);
    const r = sel.seasonal ? holtWinters(y, 12, 0.35, 0.02, 0.25, H, true) : holt(y, 0.6, 0.15, H, 0.9);
    const res = y.slice(13).map((v, i) => v - r.fitted[i + 13]);
    const sd = Math.sqrt(mean(res.map((e) => e * e)));
    const dates = futureDates(train[train.length - 1].date, H, 12);
    const fc = r.forecast.map((v, i) => ({ date: dates[i], mean: v, lo80: v - 1.2816 * sd * Math.sqrt(i + 1), hi80: v + 1.2816 * sd * Math.sqrt(i + 1), lo95: v - 1.96 * sd * Math.sqrt(i + 1), hi95: v + 1.96 * sd * Math.sqrt(i + 1) }));
    const actual = s.data.slice(originIdx + 1, originIdx + 1 + H);
    const inside = actual.filter((a, i) => a.value >= fc[i].lo80 && a.value <= fc[i].hi80).length;
    return { train, fc, actual, inside };
  });

  function draw() {
    if (!el || !model) return;
    const { train, fc, actual } = model;
    const hist = train.slice(-72);
    const last = hist[hist.length - 1];
    const join = [{ date: last.date, mean: last.value, lo80: last.value, hi80: last.value, lo95: last.value, hi95: last.value }, ...fc];
    const W = el.clientWidth;
    const marks: any[] = [
      Plot.areaY(join, { x: 'date', y1: 'lo95', y2: 'hi95', fill: C.forecast, fillOpacity: 0.13, curve: 'monotone-x' }),
      Plot.areaY(join, { x: 'date', y1: 'lo80', y2: 'hi80', fill: C.forecast, fillOpacity: 0.24, curve: 'monotone-x' }),
      Plot.lineY(hist, { x: 'date', y: 'value', stroke: C.history, strokeWidth: 1.8 }),
      Plot.lineY(join, { x: 'date', y: 'mean', stroke: C.forecast, strokeWidth: 2.8 }),
      Plot.ruleX([last.date], { stroke: C.borderStrong, strokeDasharray: '3,4' }),
      Plot.text([last.date], { x: (d: any) => d, frameAnchor: 'top', dx: 6, dy: 4, textAnchor: 'start', text: () => `You are here: ${ym(last.date)}`, fill: C.text2, fontSize: 12, fontWeight: 600 }),
    ];
    if (reveal && actual.length) {
      marks.push(Plot.lineY(actual, { x: 'date', y: 'value', stroke: C.actual, strokeWidth: 2.6, className: 'reveal' }));
      marks.push(Plot.dot(actual, { x: 'date', y: 'value', fill: C.actual, r: 2.4 }));
      marks.push(Plot.text(actual.slice(-1), { x: 'date', y: 'value', text: () => 'What actually happened', dx: -6, dy: -12, textAnchor: 'end', fill: C.actual, fontWeight: 650, fontSize: 12, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' } as any));
    }
    marks.push(Plot.text(fc.slice(-1), { x: 'date', y: 'hi80', text: () => '80%', dx: 6, textAnchor: 'start', fill: C.muted, fontSize: 12 }));
    marks.push(Plot.text(fc.slice(-1), { x: 'date', y: 'hi95', text: () => '95%', dx: 6, textAnchor: 'start', fill: C.muted, fontSize: 12 }));
    marks.push(Plot.tip(fc, Plot.pointerX({ x: 'date', y: 'mean', title: (d: any) => `Forecast for ${ym(d.date)}\n${fmt(d.mean)} ${sel.unit}\n80% range: ${fmt(d.lo80)} – ${fmt(d.hi80)}` })));
    el.replaceChildren(Plot.plot({ width: W, height: Math.max(300, Math.min(440, W * 0.5)), marginLeft: 56, marginRight: 40, marginTop: 24, style: plotStyle(), x: { label: null }, y: { grid: true, nice: true, tickFormat: fmt, label: null }, marks }));
  }

  $effect(() => { model; reveal; draw(); });
  $effect(() => { sel; load(); });
  onMount(() => watchLayout(el, draw));
  const covered = $derived(model && model.actual.length ? Math.round((100 * model.inside) / model.actual.length) : null);
</script>

<div class="hf">
  <div class="hf-ctrl">
    <div class="seg" role="group" aria-label="Series">
      {#each SERIES as x}<button type="button" class:on={sel.id === x.id} aria-pressed={sel.id === x.id} onclick={() => (sel = x)}>{x.label}</button>{/each}
    </div>
    {#if s}
      <label class="sl">Stand at <input type="range" min={36} max={s.data.length - 2} bind:value={originIdx} oninput={() => (reveal = false)} aria-label="Forecast origin date" /> <b>{ym(s.data[originIdx].date)}</b></label>
    {/if}
    <button class="btn btn-primary btn-sm" onclick={() => (reveal = !reveal)} disabled={!model || !model.actual.length}>{reveal ? 'Hide the truth' : 'Reveal what happened'}</button>
  </div>
  <div bind:this={el} class="hf-chart" role="img" aria-label={`Forecast fan chart: ${sel.label}, two years ahead from ${s?.data[originIdx] ? ym(s.data[originIdx].date) : "the chosen date"}`}></div>
  <div class="hf-note" aria-live="polite">
    {#if reveal && covered !== null}
      Reality fell inside the 80% band in <b>{covered}%</b> of the {model?.actual.length} months shown.
      {#if covered < 60}A big surprise: try standing in mid-2019 and look at 2020.{:else if covered > 95}A calm period: the band was, if anything, too wide.{:else}About what a well-calibrated forecast should do.{/if}
    {:else}
      Drag the date to stand anywhere in the past, forecast two years ahead, then reveal the truth.
    {/if}
  </div>
</div>

<style>
  .hf { background: var(--surface); border: 1px solid var(--border); border-radius: 18px; padding: 1rem 1.2rem 1rem; box-shadow: var(--shadow); }
  .hf-ctrl { display: flex; flex-wrap: wrap; gap: .7rem 1.2rem; align-items: center; margin-bottom: .6rem; font-size: .85rem; color: var(--text-2); }
  .seg { display: inline-flex; background: var(--bg); border: 1px solid var(--border); border-radius: 9px; padding: 2px; flex-wrap: wrap; }
  .seg button { all: unset; cursor: pointer; font: 600 .8rem var(--font-ui); padding: .36rem .75rem; border-radius: 7px; color: var(--muted); }
  .seg button.on { background: var(--surface-3); color: var(--text); }
  .seg button:focus-visible { outline: 2px solid var(--accent-2); }
  .sl { display: inline-flex; align-items: center; gap: .6rem; }
  .sl b { font-variant-numeric: tabular-nums; color: var(--text); min-width: 5.5ch; }
  .sl input { accent-color: var(--accent); width: 170px; }
  .hf-chart { min-height: 300px; }
  .hf-chart :global(.reveal path) { stroke-dasharray: 2000; stroke-dashoffset: 2000; animation: rv 1.2s cubic-bezier(.2,0,0,1) forwards; }
  @keyframes rv { to { stroke-dashoffset: 0; } }
  .hf-note { font-size: .88rem; color: var(--text-2); min-height: 1.5em; margin-top: .3rem; }
</style>
