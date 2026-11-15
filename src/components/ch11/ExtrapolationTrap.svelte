<script lang="ts">
  // Chapter 12 · Explorable 3: the extrapolation trap. A random forest on the LEVEL of a trending
  // series cannot forecast above its training maximum; the same forest on GROWTH RATES can.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, futureDates, ym, type Pt } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { growForest, predictForest, recursiveLags, lagTable } from './tree';

  const H = 36, P = 3;
  let data: Pt[] = $state([]);
  let mode: 'level' | 'growth' = $state('level');
  let origin = $state(0);      // index of the last training month (committed)
  let dragO = $state(0);       // live slider value while dragging
  let el: HTMLDivElement;
  let res: { level: number[]; growth: number[]; dates: Date[]; act: number[]; max: number; maeL: number; maeG: number } | null = $state(null);

  const bn = (v: number) => v / 1000;
  onMount(() => {
    loadSeries('MRTSSM4541USS', { start: '2010-01-01' }).then((s) => {
      data = s.data;
      const i = data.findIndex((p) => p.date.getFullYear() === 2022 && p.date.getMonth() === 11);
      origin = dragO = i > 0 ? i : data.length - 13;
    });
    return watchLayout(el, draw);
  });
  const minO = 60;
  const maxO = $derived(Math.max(minO, data.length - 7));

  function compute() {
    if (!data.length) return;
    const hist = data.slice(0, origin + 1).map((p) => p.value);
    const n = Math.min(H, data.length - 1 - origin);
    const act = data.slice(origin + 1, origin + 1 + n).map((p) => p.value);
    const opts = { nTrees: 100, mtry: 2, minSplit: 5, seed: 7 };
    const L = lagTable(hist, P), fl = growForest(L.X, L.y, opts);
    const level = recursiveLags((x) => predictForest(fl, x), hist, P, H);
    const gr = hist.slice(1).map((v, i) => 100 * Math.log(v / hist[i]));
    const G = lagTable(gr, P), fg = growForest(G.X, G.y, opts);
    let lv = hist[hist.length - 1];
    const growth = recursiveLags((x) => predictForest(fg, x), gr, P, H).map((g) => (lv = lv * Math.exp(g / 100)));
    const mae = (f: number[]) => act.reduce((s, a, i) => s + Math.abs(a - f[i]), 0) / Math.max(1, act.length);
    res = { level, growth, dates: futureDates(data[origin].date, H, 12), act, max: Math.max(...hist), maeL: mae(level), maeG: mae(growth) };
  }
  $effect(() => { origin; data; compute(); });

  function draw() {
    if (!el || !res || !data.length) return;
    const W = el.clientWidth;
    const from = Math.max(0, origin - 84);
    const hist = data.slice(from, origin + 1).map((p) => ({ date: p.date, v: bn(p.value) }));
    const act = data.slice(origin + 1, origin + 1 + H).map((p) => ({ date: p.date, v: bn(p.value) }));
    const fc = (arr: number[]) => [{ date: data[origin].date, v: bn(data[origin].value) }, ...arr.map((v, i) => ({ date: res!.dates[i], v: bn(v) }))];
    const on = fc(mode === 'level' ? res.level : res.growth), off = fc(mode === 'level' ? res.growth : res.level);
    const mx = bn(res.max), end = res.dates[res.dates.length - 1];
    const top = Math.max(mx, ...act.map((d) => d.v), ...on.map((d) => d.v), ...off.map((d) => d.v)) * 1.04;
    el.replaceChildren(Plot.plot({
      width: W, height: Math.max(280, Math.min(380, W * 0.5)), marginLeft: 48, marginRight: 118, marginTop: 18,
      style: plotStyle(), x: { label: null }, y: { grid: true, label: '$ billions', domain: [Math.min(...hist.map((d) => d.v)) * 0.95, top], tickFormat: (d: number) => d.toFixed(0) },
      marks: [
        mode === 'level' ? Plot.rectY([{ a: data[origin].date, b: end }], { x1: 'a', x2: 'b', y1: mx, y2: top, fill: C.danger, fillOpacity: 0.07 }) : null,
        mode === 'level' ? Plot.text([{ x: res.dates[2], y: (mx + top) / 2 }], { x: 'x', y: 'y', text: () => 'No tree can forecast up here', textAnchor: 'start', fill: C.danger, fontSize: 12, fontWeight: 650 }) : null,
        Plot.ruleY([mx], { stroke: C.danger, strokeDasharray: '4,4', strokeWidth: 1.5 }),
        Plot.text([{ x: data[from].date, y: mx }], { x: 'x', y: 'y', dy: -7, textAnchor: 'start', text: () => `training maximum: $${mx.toFixed(1)} bn`, fill: C.danger, fontSize: 12, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
        Plot.ruleX([data[origin].date], { stroke: C.borderStrong, strokeDasharray: '3,4' }),
        Plot.text([data[origin].date], { x: (d: any) => d, frameAnchor: 'bottom', dx: -6, dy: -4, textAnchor: 'end', text: () => 'Forecast starts', fill: C.muted, fontSize: 12 }),
        Plot.lineY(hist, { x: 'date', y: 'v', stroke: C.history, strokeWidth: 2 }),
        Plot.lineY(act, { x: 'date', y: 'v', stroke: C.actual, strokeWidth: 2.2, strokeDasharray: '5,3' }),
        Plot.lineY(off, { x: 'date', y: 'v', stroke: C.forecast, strokeWidth: 1.25, strokeOpacity: 0.4 }),
        Plot.lineY(on, { x: 'date', y: 'v', stroke: C.forecast, strokeWidth: 3 }),
        Plot.text([on[on.length - 1]], { x: 'date', y: 'v', dx: 7, textAnchor: 'start', text: () => (mode === 'level' ? 'forest on levels' : 'forest on growth'), fill: C.forecast, fontSize: 12, fontWeight: 650 }),
        Plot.text([off[off.length - 1]], { x: 'date', y: 'v', dx: 7, textAnchor: 'start', text: () => (mode === 'level' ? 'on growth' : 'on levels'), fill: C.muted, fontSize: 12 }),
        act.length ? Plot.text([act[act.length - 1]], { x: 'date', y: 'v', dx: 7, dy: -12, textAnchor: 'start', text: () => 'what happened', fill: C.actual, fontSize: 12, fontWeight: 650 }) : null,
        Plot.tip(on.slice(1), Plot.pointerX({ x: 'date', y: 'v', title: (d: any) => `${ym(d.date)}\nForecast: $${d.v.toFixed(1)} bn` })),
      ].filter(Boolean) as any,
      ariaLabel: `E-commerce sales with a random-forest forecast from ${ym(data[origin].date)}, trained on ${mode === 'level' ? 'levels' : 'growth rates'}`,
    } as any));
  }
  $effect(() => { res; mode; draw(); });
  const k$ = (v: number) => `$${(v / 1000).toFixed(1)} bn`;
</script>

<Explorable title="The extrapolation trap: a forest on levels hits an invisible ceiling" caption="A random forest (100 trees, three lags as features) forecasts U.S. e-commerce sales 36 months ahead. Switch between training it on the <b>level</b> ($) and on the <b>monthly growth rate</b> (%). Drag the <b>forecast origin</b> anywhere: on levels, the forecast never rises above the dashed red line, the highest value in the training data. Data: FRED MRTSSM4541USS, $ billions, seasonally adjusted.">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="What the forest is trained to predict">
      <button class:on={mode === 'level'} aria-pressed={mode === 'level'} onclick={() => (mode = 'level')}>Forecast the level</button>
      <button class:on={mode === 'growth'} aria-pressed={mode === 'growth'} onclick={() => (mode = 'growth')}>Forecast the growth rate</button>
    </div>
    {#if data.length}
      <label class="sl">Forecast origin <input type="range" min={minO} max={maxO} bind:value={dragO} onchange={() => (origin = dragO)} aria-valuetext={ym(data[dragO].date)} /> <b>{ym(data[dragO].date)}</b></label>
    {/if}
  {/snippet}
  {#snippet aside()}
    {#if res}
      <div class="cards">
        <div class="card" class:on={mode === 'level'}><span class="stat-l">Forest on levels: average miss</span><span class="stat-v">{k$(res.maeL)}</span></div>
        <div class="card" class:on={mode === 'growth'}><span class="stat-l">Forest on growth: average miss</span><span class="stat-v">{k$(res.maeG)}</span></div>
      </div>
      <p class="v">Highest level forecast: <b>{k$(Math.max(...res.level))}</b>, never above the training maximum of <b>{k$(res.max)}</b>.</p>
      <p class="hint">Average miss = mean absolute error over the months after the origin that we can already check (up to 36).</p>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 280px; }
  .cards { display: grid; gap: .6rem; }
  .card { display: flex; flex-direction: column; gap: .15rem; padding: .6rem .75rem; border: 1px solid var(--border); border-radius: 10px; }
  .card.on { border-color: var(--c-forecast); background: var(--surface-2); }
  .stat-l { font-size: .76rem; color: var(--muted); }
  .stat-v { font: 650 1.35rem/1.1 var(--font-ui); font-variant-numeric: tabular-nums; color: var(--text); }
  .v { font-size: .84rem; color: var(--text-2); margin: .8rem 0 .4rem; }
  .hint { font-size: .76rem; color: var(--muted); margin: 0; }
</style>
