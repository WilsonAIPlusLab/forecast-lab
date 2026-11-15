<script lang="ts">
  // Chapter 12 · Explorable 4: a forest of opinions. Each bootstrap tree gives its own one-month-ahead
  // forecast (thin lines); the forest's forecast is their average (bold). More trees -> less variance.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, ym } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { growForest, predictTree, type Forest } from './tree';

  const NT = 200;
  const SER = {
    RSXFSN: { label: 'Retail sales', unit: '$ bn', scale: 1 / 1000, dec: 0, fred: 'RSXFSN, $ millions, not seasonally adjusted' },
    HOUST: { label: 'Housing starts', unit: 'thousand units (annual rate)', scale: 1, dec: 0, fred: 'HOUST, thousands of units at a seasonally adjusted annual rate' },
  } as const;
  type Sid = keyof typeof SER;
  let sid: Sid = $state('RSXFSN');
  let mtry = $state(2);
  let k = $state(1);
  let el: HTMLDivElement;
  let mini: HTMLDivElement | undefined = $state();
  type Row = { date: Date; x: number[]; g: number; prev: number; lev: number };
  let rows: Record<string, { tr: Row[]; te: Row[] }> = {};
  const cache = new Map<string, { preds: number[][]; curve: number[]; single: number[] }>();
  let cur: { preds: number[][]; curve: number[]; single: number[]; te: Row[]; naive: number } | null = $state(null);

  async function prep(id: Sid) {
    if (rows[id]) return rows[id];
    const s = await loadSeries(id, { start: '2009-01-01' });
    const d = s.data, g = d.map((p, i) => (i ? 100 * Math.log(p.value / d[i - 1].value) : NaN));
    const R: Row[] = [];
    for (let t = 13; t < d.length; t++) R.push({ date: d[t].date, x: [g[t - 1], g[t - 2], g[t - 12], d[t].date.getMonth() + 1], g: g[t], prev: d[t - 1].value, lev: d[t].value });
    return (rows[id] = { tr: R.filter((r) => r.date.getFullYear() < 2023), te: R.filter((r) => r.date.getFullYear() >= 2023) });
  }
  async function compute() {
    const id = sid, m = mtry, key = `${id}-${m}`;
    const { tr, te } = await prep(id);
    if (!cache.has(key)) {
      const F: Forest = growForest(tr.map((r) => r.x), tr.map((r) => r.g), { nTrees: NT, mtry: m, minSplit: 5, seed: 3 });
      // each tree's one-step level forecast: last month's actual level x exp(predicted growth)
      const preds = F.trees.map((T) => te.map((r) => r.prev * Math.exp(predictTree(T, r.x) / 100)));
      const mae = (f: number[]) => te.reduce((s, r, i) => s + Math.abs(r.lev - f[i]), 0) / te.length;
      const single = preds.map(mae);
      const sum = te.map(() => 0), curve: number[] = [];
      preds.forEach((p, b) => { p.forEach((v, i) => (sum[i] += v)); curve.push(mae(sum.map((s) => s / (b + 1)))); });
      cache.set(key, { preds, curve, single });
    }
    if (id !== sid || m !== mtry) return;
    const naive = te.reduce((s, r) => s + Math.abs(r.lev - r.prev), 0) / te.length;
    cur = { ...cache.get(key)!, te, naive };
  }
  $effect(() => { sid; mtry; compute(); });

  const stats = $derived.by(() => {
    if (!cur) return null;
    const s = cur.single.slice(0, k);
    return { single: s.reduce((a, b) => a + b, 0) / s.length, forest: cur.curve[k - 1], naive: cur.naive };
  });
  const f = (v: number) => (v * SER[sid].scale).toLocaleString(undefined, { maximumFractionDigits: SER[sid].scale < 1 ? 1 : 0 });

  function draw() {
    if (!el || !cur) return;
    const W = el.clientWidth, sc = SER[sid].scale;
    const te = cur.te;
    const thin = cur.preds.slice(0, k).flatMap((p, b) => p.map((v, i) => ({ date: te[i].date, v: v * sc, b })));
    const avg = te.map((r, i) => ({ date: r.date, v: (cur!.preds.slice(0, k).reduce((s, p) => s + p[i], 0) / k) * sc }));
    const act = te.map((r) => ({ date: r.date, v: r.lev * sc }));
    const op = k === 1 ? 0.9 : Math.max(0.08, Math.min(0.4, 3 / k));
    el.replaceChildren(Plot.plot({
      width: W, height: Math.max(270, Math.min(360, W * 0.46)), marginLeft: 52, marginRight: 104, marginTop: 14,
      style: plotStyle(), x: { label: null }, y: { grid: true, label: SER[sid].unit, tickFormat: (d: number) => d.toLocaleString() },
      marks: [
        Plot.lineY(thin, { x: 'date', y: 'v', z: 'b', stroke: C.s[4], strokeWidth: 1.25, strokeOpacity: op }),
        Plot.lineY(act, { x: 'date', y: 'v', stroke: C.actual, strokeWidth: 2.2, strokeDasharray: '5,3' }),
        k > 1 ? Plot.lineY(avg, { x: 'date', y: 'v', stroke: C.forecast, strokeWidth: 3 }) : null,
        Plot.text([act[act.length - 1]], { x: 'date', y: 'v', dx: 7, dy: -8, textAnchor: 'start', text: () => 'what happened', fill: C.actual, fontSize: 12, fontWeight: 650 }),
        Plot.text([avg[avg.length - 1]], { x: 'date', y: 'v', dx: 7, dy: 10, textAnchor: 'start', text: () => (k > 1 ? `average of ${k} trees` : 'one tree'), fill: k > 1 ? C.forecast : C.s[4], fontSize: 12, fontWeight: 650 }),
        Plot.tip(avg, Plot.pointerX({ x: 'date', y: 'v', title: (d: any, i: number) => `${ym(d.date)}\nForest (${k} trees): ${d.v.toLocaleString(undefined, { maximumFractionDigits: 1 })} ${SER[sid].unit}\nActual: ${act[i]?.v.toLocaleString(undefined, { maximumFractionDigits: 1 })}` })),
      ].filter(Boolean) as any,
      ariaLabel: `${k} tree forecasts and their average against actual ${SER[sid].label.toLowerCase()}, 2023 onward`,
    } as any));
    if (mini) {
      const c = cur.curve.map((v, i) => ({ k: i + 1, v: v * sc }));
      mini.replaceChildren(Plot.plot({
        width: mini.clientWidth, height: 120, marginLeft: 40, marginRight: 8, marginTop: 8, marginBottom: 28, style: plotStyle(),
        x: { label: 'number of trees', type: 'log', ticks: [1, 10, 100], tickFormat: (d: number) => String(d) }, y: { grid: true, label: null, ticks: 3, tickFormat: (d: number) => d.toLocaleString() },
        marks: [Plot.lineY(c, { x: 'k', y: 'v', stroke: C.forecast, strokeWidth: 2 }), Plot.dot([c[k - 1]], { x: 'k', y: 'v', r: 4.5, fill: C.forecast }),
          Plot.ruleY([cur.naive * sc], { stroke: C.muted, strokeDasharray: '4,4' })],
        ariaLabel: 'Forest error falls quickly as trees are added, then levels off',
      } as any));
    }
  }
  $effect(() => { cur; k; draw(); });
  onMount(() => watchLayout(el, draw));
</script>

<Explorable title="A forest is a crowd of noisy trees whose average is steady" caption="Each thin line is one tree's one-month-ahead forecast for 2023 onward. Every tree was grown on a different <b>bootstrap sample</b> of 2010–2022 months, so each has its own opinion. The bold line is their <b>average</b>, the forest's forecast. Slide the number of trees up from 1 and watch the spread wash out and the error fall. Switch to <b>all 4 features</b> to see plain bagging: its trees are more alike, so averaging helps a little less. Features: growth 1, 2 and 12 months ago, and the calendar month.">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Series">
      {#each Object.entries(SER) as [id, s]}<button class:on={sid === id} aria-pressed={sid === id} onclick={() => (sid = id as Sid)}>{s.label}</button>{/each}
    </div>
    <div class="seg" role="group" aria-label="Features each split may consider">
      <button class:on={mtry === 2} aria-pressed={mtry === 2} onclick={() => (mtry = 2)}>2 random features per split</button>
      <button class:on={mtry === 4} aria-pressed={mtry === 4} onclick={() => (mtry = 4)}>All 4 (bagging)</button>
    </div>
    <label class="sl">Trees <input type="range" min="1" max={NT} bind:value={k} aria-valuetext={`${k} trees`} /> <b>{k}</b></label>
  {/snippet}
  {#snippet aside()}
    {#if stats}
      <div class="st"><span class="stat-l">Typical single tree: average miss</span><span class="stat-v">{f(stats.single)}</span></div>
      <div class="st"><span class="stat-l">Forest of {k}: average miss</span><span class="stat-v fo">{f(stats.forest)}</span></div>
      <div class="st"><span class="stat-l">Naive (last month's value)</span><span class="stat-v mu">{f(stats.naive)}</span></div>
      <div bind:this={mini} class="mini"></div>
      <p class="hint">Average miss = test-period MAE, {SER[sid].unit}. Dashed line: naive. Data: FRED {SER[sid].fred}.</p>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 270px; }
  .st { display: flex; flex-direction: column; gap: .1rem; margin-bottom: .6rem; }
  .stat-l { font-size: .76rem; color: var(--muted); }
  .stat-v { font: 650 1.35rem/1.1 var(--font-ui); font-variant-numeric: tabular-nums; color: var(--text); }
  .stat-v.fo { color: var(--c-forecast); } .stat-v.mu { color: var(--muted); }
  .mini { min-height: 120px; }
  .hint { font-size: .74rem; color: var(--muted); margin: .3rem 0 0; }
</style>
