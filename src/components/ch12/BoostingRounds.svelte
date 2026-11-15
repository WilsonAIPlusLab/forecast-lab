<script lang="ts">
  // Signature explorable 1: gradient boosting, one tree at a time, on real U.S. retail sales.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, ym } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { buildTable, boost, treeRules, type Row, type BoostRun } from './boost';

  const MAXR = 300;
  const ETAS = [0.1, 0.3, 1];
  const DEPTHS = [1, 2, 3];
  let eta = $state(0.1);
  let depth = $state(2);
  let k = $state(0);
  let rows: Row[] = $state([]);
  let isTrain: boolean[] = [];
  let run = $state<BoostRun | null>(null);
  let busy = $state(false);
  let el: HTMLDivElement;
  let elCurve: HTMLDivElement | undefined = $state();
  const cache = new Map<string, BoostRun>();

  onMount(() => {
    loadSeries('RSXFSN').then((s) => {
      rows = buildTable(s.data);
      isTrain = rows.map((r) => r.date < new Date('2023-01-01T00:00:00'));
      compute();
    });
    return watchLayout(el, draw);
  });

  function compute() {
    if (!rows.length) return;
    const key = `${eta}-${depth}`;
    if (!cache.has(key)) {
      busy = true;
      setTimeout(() => { cache.set(key, boost(rows, isTrain, eta, depth, MAXR)); run = cache.get(key)!; busy = false; }, 20);
    } else run = cache.get(key)!;
  }

  const bn = (v: number) => v / 1000;
  const view = $derived.by(() => {
    if (!run) return null;
    const F = run.pred[k];
    const first = rows.findIndex((r) => r.date >= new Date('2016-01-01T00:00:00'));
    const pts = rows.slice(first).map((r, j) => {
      const i = first + j;
      const fit = r.lag1 * (1 + F[i] / 100);
      return { date: r.date, actual: bn(r.sales), fit: bn(fit), res: bn(r.sales - fit), test: !isTrain[i] };
    });
    return { pts, trainR: bn(run.trainRMSE[k]), testR: bn(run.testRMSE[k]), best: run.testRMSE.indexOf(Math.min(...run.testRMSE)), minTest: bn(Math.min(...run.testRMSE)) };
  });
  const rules = $derived(run && k > 0 ? treeRules(run.trees[k - 1]).sort((a, b) => Math.abs(b.value) - Math.abs(a.value)) : []);

  function draw() {
    if (!el || !view || !run) return;
    const W = el.clientWidth;
    const testStart = view.pts.find((p) => p.test)!.date, last = view.pts[view.pts.length - 1].date;
    const shade = Plot.rectX([{ a: testStart, b: last }], { x1: 'a', x2: 'b', fill: C.actual, fillOpacity: 0.06 });
    const top = Plot.plot({
      width: W, height: Math.max(230, Math.min(300, W * 0.36)), marginLeft: 52, marginRight: 12, marginTop: 16,
      style: plotStyle(), x: { label: null }, y: { grid: true, label: '$bn', tickFormat: (v: number) => `$${v}` },
      ariaLabel: `Retail sales and the boosted model's one-month-ahead fit after ${k} trees`,
      marks: [
        shade,
        Plot.text([testStart], { x: (d: any) => d, frameAnchor: 'top', dx: 6, dy: 2, textAnchor: 'start', text: () => 'Held out (never used for fitting)', fill: C.muted, fontSize: 12 }),
        Plot.lineY(view.pts, { x: 'date', y: 'actual', stroke: C.history, strokeWidth: 1.25, strokeOpacity: 0.55 }),
        Plot.lineY(view.pts, { x: 'date', y: 'fit', z: 'test', stroke: (p: any) => (p.test ? C.forecast : C.fitted), strokeWidth: 2.2 }),
        Plot.tip(view.pts, Plot.pointerX({ x: 'date', y: 'fit', title: (p: any) => `${ym(p.date)}\nActual: $${p.actual.toFixed(1)}bn\nModel: $${p.fit.toFixed(1)}bn\nMiss: ${p.res >= 0 ? '+' : '−'}$${Math.abs(p.res).toFixed(1)}bn` })),
      ],
    });
    const yMax = Math.max(60, ...view.pts.map((p) => Math.abs(p.res)));
    const bottom = Plot.plot({
      width: W, height: 160, marginLeft: 52, marginRight: 12, marginTop: 20,
      style: plotStyle(), x: { label: null }, y: { grid: true, label: 'Miss, $bn', domain: [-yMax, yMax], tickFormat: (v: number) => (v > 0 ? `+${v}` : `${v}`) },
      ariaLabel: 'Residuals: actual minus model, in billions of dollars',
      marks: [
        shade,
        Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
        Plot.ruleX(view.pts, { x: 'date', y1: 0, y2: 'res', stroke: (p: any) => (p.test ? C.forecast : C.fitted), strokeWidth: 2.4, strokeOpacity: 0.85 }),
      ],
    });
    el.replaceChildren(top, bottom);
    if (elCurve) {
      const curve = run.trainRMSE.map((v, i) => ({ i, v: bn(v), s: 'Training' })).concat(run.testRMSE.map((v, i) => ({ i, v: bn(v), s: 'Held out' })));
      const cw = elCurve.clientWidth || 250;
      elCurve.replaceChildren(Plot.plot({
        width: cw, height: 170, marginLeft: 34, marginRight: 66, marginTop: 10, marginBottom: 24,
        style: plotStyle(), x: { label: null, domain: [0, MAXR], ticks: [0, 100, 200, 300] }, y: { grid: true, label: null, domain: [0, 50] },
        ariaLabel: 'Error versus number of trees, training and held-out',
        marks: [
          Plot.lineY(curve, { x: 'i', y: 'v', z: 's', stroke: (d: any) => (d.s === 'Training' ? C.fitted : C.forecast), strokeWidth: 2 }),
          Plot.text(curve, Plot.selectLast({ x: 'i', y: 'v', z: 's', text: 's', dx: 5, textAnchor: 'start', fill: (d: any) => (d.s === 'Training' ? C.fitted : C.forecast), fontSize: 12 })),
          Plot.ruleX([k], { stroke: C.text, strokeDasharray: '3,3' }),
          Plot.dot([{ i: k, v: bn(run.testRMSE[k]) }, { i: k, v: bn(run.trainRMSE[k]) }], { x: 'i', y: 'v', fill: C.text, r: 3.5 }),
        ],
      }));
    }
  }
  $effect(() => { view; elCurve; draw(); });
  $effect(() => { eta; depth; compute(); });
  const signed = (v: number) => `${v >= 0 ? '+' : '−'}${Math.abs(v).toFixed(2)}`;
</script>

<Explorable title="Each tree fixes part of the misses, until extra trees start fitting noise" caption="Each new tree is fitted to the <b>misses</b> (residuals) of all the trees before it, and only a fraction of it (the learning rate) is added. Cyan is the fit on the training years (1993 to 2022, only 2016 onward shown); violet is the one-month-ahead forecast for held-out months it never trained on. Drag the slider, then try learning rate 1 with depth-3 trees. Data: FRED RSXFSN, U.S. retail sales excluding food services, NSA, $ billions.">
  {#snippet controls()}
    <label class="sl">Trees <input type="range" min="0" max={MAXR} bind:value={k} aria-label="Number of boosting rounds" aria-valuetext={`${k} trees`} /> <b>{k}</b></label>
    <span class="grp"><span class="lab" id="lr-l">Learning rate</span>
      <span class="seg" role="group" aria-labelledby="lr-l">{#each ETAS as e}<button class:on={eta === e} aria-pressed={eta === e} onclick={() => (eta = e)}>{e}</button>{/each}</span></span>
    <span class="grp"><span class="lab" id="dp-l">Tree depth</span>
      <span class="seg" role="group" aria-labelledby="dp-l">{#each DEPTHS as dd}<button class:on={depth === dd} aria-pressed={depth === dd} onclick={() => (depth = dd)}>{dd}</button>{/each}</span></span>
  {/snippet}
  {#snippet aside()}
    {#if view}
      <div class="side" aria-live="polite">
        <div class="stats">
          <div class="stat"><span class="stat-v">${view.trainR.toFixed(1)}bn</span><span class="stat-l">training error (RMSE)</span></div>
          <div class="stat"><span class="stat-v held">${view.testR.toFixed(1)}bn</span><span class="stat-l">held-out error (RMSE)</span></div>
        </div>
        <div class="curve-h">RMSE in $ billions, by number of trees</div>
        <div bind:this={elCurve} class="curve"></div>
        <p class="note">Lowest held-out error: <b>${view.minTest.toFixed(1)}bn</b> after {view.best} trees.</p>
        <div class="tree">
          {#if k === 0}
            <p>No trees yet. Every month gets the same prediction: the average monthly growth, <b>{run?.base.toFixed(2)}%</b>. That misses every December by tens of billions.</p>
          {:else}
            <p class="th">Tree {k} says:</p>
            <ul>{#each rules.slice(0, 4) as r}<li>If {r.rule}: <b>{signed(eta * r.value)}</b> pts of growth <span class="n">({r.n} months)</span></li>{/each}</ul>
            {#if rules.length > 4}<p class="n">…and {rules.length - 4} leaves with smaller corrections.</p>{/if}
          {/if}
        </div>
      </div>
    {/if}
  {/snippet}
  <div class="wrap">
    {#if busy}<div class="busy" role="status">Growing {MAXR} trees…</div>{/if}
    <div bind:this={el} class="chart"></div>
  </div>
</Explorable>

<style>
  .wrap { position: relative; }
  .chart { min-height: 380px; }
  .busy { position: absolute; top: .4rem; right: .4rem; font-size: .8rem; color: var(--muted); background: var(--surface-2); padding: .2rem .6rem; border-radius: 6px; z-index: 2; }
  .grp { display: inline-flex; align-items: center; gap: .5rem; }
  .lab { font-size: .82rem; }
  .side { font-size: .84rem; color: var(--text-2); }
  .stats { display: flex; gap: 1.1rem; margin-bottom: .4rem; }
  .stat-v { font-size: 1.25rem !important; }
  .held { color: var(--c-forecast) !important; }
  .curve { min-height: 170px; }
  .curve-h { font-size: .76rem; color: var(--muted); margin-top: .2rem; }
  .note { margin: .3rem 0 .6rem; color: var(--muted); font-size: .8rem; }
  .tree { border-top: 1px solid var(--border); padding-top: .5rem; }
  .tree p { margin: 0 0 .35rem; }
  .th { font-weight: 650; color: var(--text); }
  .tree ul { margin: 0; padding-left: 1rem; }
  .tree li { margin: .15rem 0; line-height: 1.4; }
  .tree b { font-variant-numeric: tabular-nums; color: var(--text); }
  .n { color: var(--muted); font-size: .76rem; }
</style>
