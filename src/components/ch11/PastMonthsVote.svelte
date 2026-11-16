<script lang="ts">
  // Chapter 11 · Explorable 6: a tree's forecast is an average of past months. Pick a month to forecast;
  // see the questions a small tree asks (in words), and which training months it averages. Switch to the
  // forest to see its forecast as a weighted average of many past months.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, ym } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { growTree, mulberry, type TNode } from './tree';

  const MON = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  const NT = 150;
  const PLURAL = ['Januaries', 'Februaries', 'Marches', 'Aprils', 'Mays', 'Junes', 'Julys', 'Augusts', 'Septembers', 'Octobers', 'Novembers', 'Decembers'];
  type Row = { date: Date; x: number[]; y: number };
  let tr: Row[] = [], te: Row[] = $state([]);
  let tree: TNode | null = null;
  let forest: { T: TNode; idx: number[] }[] = [];
  let ready = $state(false);
  let mode: 'tree' | 'forest' = $state('tree');
  let k = $state(0);          // index into the test months
  let el: HTMLDivElement;

  onMount(() => {
    loadSeries('RSXFSN', { start: '2010-01-01' }).then((s) => {
      const d = s.data, g = d.map((p, i) => (i ? 100 * Math.log(p.value / d[i - 1].value) : NaN));
      const R: Row[] = [];
      for (let t = 13; t < d.length; t++) R.push({ date: d[t].date, x: [g[t - 1], g[t - 2], g[t - 12], d[t].date.getMonth() + 1], y: g[t] });
      tr = R.filter((r) => r.date.getFullYear() < 2023);
      te = R.filter((r) => r.date.getFullYear() >= 2023);
      const X = tr.map((r) => r.x), y = tr.map((r) => r.y), all = tr.map((_, i) => i);
      tree = growTree(X, y, all, { maxDepth: 3, minLeaf: 5, minSplit: 10 });
      const rng = mulberry(3);
      forest = Array.from({ length: NT }, () => {
        const idx = Array.from({ length: y.length }, () => Math.floor(rng() * y.length));
        return { T: growTree(X, y, idx, { mtry: 2, minSplit: 5, rng }), idx };
      });
      const dec = te.findIndex((r) => r.date.getMonth() === 11);
      k = dec >= 0 ? dec : 0;
      ready = true;
    });
    return watchLayout(el, draw);
  });

  const leaf = (t: TNode, x: number[]) => { let n = t; while (n.l && n.r) n = x[n.f!] <= n.thr! ? n.l : n.r; return n; };
  const NAMES = ['last month', 'two months ago', 'in the same month last year'];
  /** A split in plain words, phrased so the answer "yes" sends the month left (feature <= threshold). */
  function question(f: number, thr: number) {
    if (f === 3) {
      const m = Math.floor(thr);
      return m === 1 ? 'Is it January?' : m === 11 ? 'Is it any month before December?' : `Is it ${MON[0]}–${MON[m - 1]} (rather than ${MON[m]}–December)?`;
    }
    return `Was growth ${NAMES[f]} at or below ${thr.toFixed(1)}%?`;
  }

  const view = $derived.by(() => {
    if (!ready || !tree || !te.length) return null;
    const r = te[Math.min(k, te.length - 1)];
    const w = new Array(tr.length).fill(0);
    const path: { q: string; yes: boolean }[] = [];
    let fc = 0, nLeaf = 0;
    if (mode === 'tree') {
      let n = tree;
      while (n.l && n.r) { const yes = r.x[n.f!] <= n.thr!; path.push({ q: question(n.f!, n.thr!), yes }); n = yes ? n.l : n.r; }
      const L = n, mem = tr.map((_, i) => i).filter((i) => leaf(tree!, tr[i].x) === L);
      mem.forEach((i) => (w[i] = 1 / mem.length));
      fc = L.value; nLeaf = mem.length;
    } else {
      for (const { T, idx } of forest) {
        const L = leaf(T, r.x), mem = idx.filter((i) => leaf(T, tr[i].x) === L);
        mem.forEach((i) => (w[i] += 1 / mem.length / NT));
      }
      fc = w.reduce((s, wi, i) => s + wi * tr[i].y, 0);
    }
    const pts = tr.map((t, i) => ({ date: t.date, y: t.y, w: w[i], same: t.date.getMonth() === r.date.getMonth() }));
    const used = pts.filter((p) => p.w > 1e-9);
    const sameShare = used.filter((p) => p.same).reduce((s, p) => s + p.w, 0);
    const top = used.slice().sort((a, b) => b.w - a.w).slice(0, 5);
    return { r, fc, path, nLeaf, pts, used: used.length, sameShare, top, max: Math.max(...tr.map((t) => t.y)), min: Math.min(...tr.map((t) => t.y)) };
  });

  function draw() {
    const v = view;
    if (!el || !v) return;
    const W = el.clientWidth;
    if (W < 200) return;   // not laid out yet: watchLayout redraws once it has a real width
    const wmax = Math.max(...v.pts.map((p) => p.w));
    const x0 = v.pts[0].date, x1 = v.r.date;
    el.replaceChildren(Plot.plot({
      width: W, height: Math.max(280, Math.min(360, W * 0.48)), marginLeft: 44, marginRight: 16, marginTop: 22, marginBottom: 30,
      style: plotStyle(), x: { label: null }, y: { grid: true, label: 'monthly growth, %', tickFormat: (d: number) => `${d}` },
      r: { type: 'sqrt', domain: [0, wmax], range: [0, mode === 'tree' ? 5 : W < 520 ? 7 : 10] },   // tree: equal weights, so one modest size
      marks: [
        Plot.ruleY([0], { stroke: C.borderStrong }),
        Plot.dot(v.pts.filter((p) => p.w <= 1e-9), { x: 'date', y: 'y', r: 2, fill: C.muted, fillOpacity: 0.35 }),
        Plot.dot(v.pts.filter((p) => p.w > 1e-9), { x: 'date', y: 'y', r: 'w', fill: C.forecast, fillOpacity: 0.75, stroke: C.surface, strokeWidth: 0.5 }),
        Plot.ruleY([v.fc], { x1: x0, x2: x1, stroke: C.forecast, strokeWidth: 2, strokeDasharray: '6,4' }),
        Plot.text([{ x: x0, y: v.fc }], { x: 'x', y: 'y', dy: -8, textAnchor: 'start', text: () => `forecast = ${mode === 'tree' ? 'average of purple months' : 'weighted average'}: ${v.fc.toFixed(1)}%`, fill: C.forecast, fontSize: 12, fontWeight: 650, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
        Plot.dot([{ x: v.r.date, y: v.fc }], { x: 'x', y: 'y', r: 6, symbol: 'diamond', fill: C.forecast }),
        Plot.dot([{ x: v.r.date, y: v.r.y }], { x: 'x', y: 'y', r: 5.5, fill: C.actual, stroke: C.surface, strokeWidth: 1 }),
        Plot.text([{ x: v.r.date, y: v.r.y }], { x: 'x', y: 'y', dx: -9, textAnchor: 'end', text: () => `actual ${v.r.y.toFixed(1)}%`, fill: C.actual, fontSize: 12, fontWeight: 650, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
        Plot.tip(v.pts, Plot.pointer({ x: 'date', y: 'y', title: (d: any) => `${ym(d.date)}: growth ${d.y.toFixed(1)}%\nWeight in this forecast: ${(100 * d.w).toFixed(1)}%` })),
      ],
      ariaLabel: `Retail sales growth for every training month 2011 to 2022. The ${mode === 'tree' ? 'tree' : 'forest'} forecast for ${ym(v.r.date)} is ${v.fc.toFixed(1)} percent, an average of ${v.used} past months; actual growth was ${v.r.y.toFixed(1)} percent.`,
    } as any));
  }
  $effect(() => { view; draw(); });
</script>

<Explorable title="A tree's forecast is an average of past months that answered the same questions" caption="Pick a month in 2023 or later to forecast. The dots are monthly retail sales growth for every training month, 2011–2022. <b>One tree</b> (three questions deep) asks its questions in plain words, lands in a leaf, and forecasts the plain average of the past months in that leaf (purple). The <b>forest</b> ({NT} trees) gives every past month a weight, shown by dot size, and forecasts the weighted average. Either way, the forecast can never leave the range of past growth rates. Hover a dot for its weight. Data: FRED RSXFSN, not seasonally adjusted.">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Model">
      <button class:on={mode === 'tree'} aria-pressed={mode === 'tree'} onclick={() => (mode = 'tree')}>One tree (3 questions)</button>
      <button class:on={mode === 'forest'} aria-pressed={mode === 'forest'} onclick={() => (mode = 'forest')}>Forest ({NT} trees)</button>
    </div>
    {#if te.length}
      <label class="sl">Month to forecast <input type="range" min="0" max={te.length - 1} bind:value={k} aria-valuetext={ym(te[k].date)} /> <b>{ym(te[k].date)}</b></label>
    {/if}
  {/snippet}
  {#snippet aside()}
    {#if view}
      {#if mode === 'tree'}
        <p class="ah">The tree's questions for {ym(view.r.date)}</p>
        <ol class="path">
          {#each view.path as p}<li>{p.q} <b class:yes={p.yes}>{p.yes ? 'Yes' : 'No'}</b></li>{/each}
        </ol>
        <p class="v">Leaf: <b>{view.nLeaf} past months</b>. Their average growth, <b>{view.fc.toFixed(1)}%</b>, is the forecast.</p>
      {:else}
        <p class="ah">Who votes for {ym(view.r.date)}?</p>
        <p class="v"><b>{view.used}</b> past months get some weight. <b>{Math.round(100 * view.sameShare)}%</b> of the weight sits on past {PLURAL[view.r.date.getMonth()]}.</p>
        <ol class="path top">
          {#each view.top as p}<li>{ym(p.date)}: growth {p.y.toFixed(1)}%, weight <b>{(100 * p.w).toFixed(1)}%</b></li>{/each}
        </ol>
      {/if}
      <p class="v">Forecast <b class="fc">{view.fc.toFixed(1)}%</b> · actual <b class="ac">{view.r.y.toFixed(1)}%</b></p>
      <p class="hint">Past growth ranged from {view.min.toFixed(1)}% to {view.max.toFixed(1)}%. No average of those months can fall outside that range.</p>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 280px; }
  .ah { font-size: .8rem; font-weight: 650; color: var(--text); margin: 0 0 .4rem; }
  .path { margin: 0 0 .7rem; padding-left: 1.1rem; font-size: .82rem; color: var(--text-2); line-height: 1.45; }
  .path li { margin: .25rem 0; }
  .path b { color: var(--danger); }
  .path b.yes { color: var(--good); }
  .path.top b { color: var(--c-forecast); }
  .v { font-size: .84rem; color: var(--text-2); margin: .3rem 0 .5rem; }
  .fc { color: var(--c-forecast); } .ac { color: var(--c-actual); }
  .hint { font-size: .74rem; color: var(--muted); margin: 0; }
</style>
