<script lang="ts">
  // Explorable: reading the learning-rate / number-of-trees trade-off.
  // Boosts the real retail-sales table in the browser (same engine as "Boosting, one tree at a time") at four
  // learning rates and plots held-out RMSE against trees, or against trees x learning rate (the "learning budget").
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { buildTable, boost, type Row } from './boost';

  const MAXR = 300;                       // trees per run
  const ETAS = [0.05, 0.1, 0.3, 1];       // learning rates compared
  const DEPTHS = [1, 2, 3];
  const ZONE = 1.05;                      // "good zone" = within 5% of a curve's lowest held-out error
  let depth = $state(3);
  let xmode: 'trees' | 'budget' = $state('trees');
  let rows: Row[] = [];
  let isTrain: boolean[] = [];
  type Curve = { eta: number; rmse: number[]; best: number; min: number; first: number; last: number; count: number; train300: number };
  let curves = $state<Curve[] | null>(null);
  let busy = $state(false);
  let el: HTMLDivElement;
  const cache = new Map<number, Curve[]>();

  function summarize(eta: number, test: number[], train: number[]): Curve {
    const r = test.map((v) => v / 1000);                       // $ millions -> $ billions
    const min = Math.min(...r), best = r.indexOf(min);
    const inZone = r.map((v, i) => [v, i] as const).filter(([v]) => v <= min * ZONE).map(([, i]) => i);
    return { eta, rmse: r, best, min, first: inZone[0], last: inZone[inZone.length - 1], count: inZone.length, train300: train[MAXR] / 1000 };
  }

  function compute() {
    if (!rows.length) return;
    const dd = depth;
    if (cache.has(dd)) { curves = cache.get(dd)!; return; }
    busy = true;
    const out: Curve[] = [];
    const step = (k: number) => {                               // one learning rate per tick keeps the page responsive
      const run = boost(rows, isTrain, ETAS[k], dd, MAXR);
      out.push(summarize(ETAS[k], run.testRMSE, run.trainRMSE));
      if (k + 1 < ETAS.length) setTimeout(() => step(k + 1), 0);
      else { cache.set(dd, out); if (depth === dd) { curves = out; busy = false; } }
    };
    setTimeout(() => step(0), 20);
  }

  onMount(() => {
    loadSeries('RSXFSN').then((s) => {
      rows = buildTable(s.data);
      isTrain = rows.map((r) => r.date < new Date('2023-01-01T00:00:00'));
      compute();
    });
    return watchLayout(el, draw);
  });

  const col = (i: number) => C.s[[0, 2, 3, 1][i]];             // colour-blind-safe set; rate 1 gets the warm red
  function draw() {
    if (!el || !curves) return;
    const W = el.clientWidth;
    const budget = xmode === 'budget';
    const pts = curves.flatMap((c, ci) => c.rmse.map((v, k) => ({ ci, eta: c.eta, k, x: budget ? k * c.eta : k, v, zone: v <= c.min * ZONE })));
    const xMax = budget ? 30 : MAXR;
    const vis = pts.filter((p) => p.x <= xMax);
    const zone = vis.filter((p) => p.zone);
    const lastPt = curves.map((c, ci) => { const v = vis.filter((p) => p.ci === ci); return v[v.length - 1]; });
    const bestPt = curves.map((c, ci) => ({ ci, x: budget ? c.best * c.eta : c.best, v: c.min })).filter((p) => p.x <= xMax);
    const H = Math.max(280, Math.min(380, W * 0.5)), Y0 = 10, Y1 = 24;
    // end-of-line labels, nudged apart so they never overlap (at least 15 px between them)
    const gap = ((Y1 - Y0) * 15) / (H - 66);
    const labels = lastPt.filter(Boolean).map((p) => ({ ...p, ly: Math.min(Y1, Math.max(Y0, p.v)) })).sort((a, b) => a.ly - b.ly);
    for (let i = 1; i < labels.length; i++) labels[i].ly = Math.max(labels[i].ly, labels[i - 1].ly + gap);
    const over = labels.length ? labels[labels.length - 1].ly - Y1 : 0;
    if (over > 0) labels.forEach((l) => (l.ly -= over));
    el.replaceChildren(Plot.plot({
      width: W, height: H, marginLeft: 48, marginRight: W < 500 ? 62 : 80, marginTop: 24, marginBottom: 42,
      style: plotStyle(),
      ariaLabel: budget
        ? 'Held-out error against trees times learning rate. The curves for learning rates 0.05, 0.1 and 0.3 nearly coincide; learning rate 1 stays higher.'
        : 'Held-out error against the number of trees for four learning rates. Smaller rates need more trees; rate 1 dips briefly and then rises.',
      x: { label: budget ? 'Trees × learning rate (the learning budget)' : 'Number of trees', domain: [0, xMax], grid: true },
      y: { label: 'Held-out RMSE, $bn', domain: [Y0, Y1], grid: true, tickFormat: (v: number) => `$${v}` },
      marks: [
        Plot.lineY(vis, { x: 'x', y: 'v', z: 'ci', stroke: (p: any) => col(p.ci), strokeWidth: 1.4, strokeOpacity: 0.55, clip: true }),
        Plot.dot(zone, { x: 'x', y: 'v', fill: (p: any) => col(p.ci), r: 1.6, clip: true }),
        Plot.dot(bestPt, { x: 'x', y: 'v', r: 5, fill: (p: any) => col(p.ci), stroke: C.surface, strokeWidth: 1.5 }),
        Plot.text(labels, { x: 'x', y: 'ly', text: (p: any) => `rate ${p.eta}`, dx: 6, textAnchor: 'start', fill: (p: any) => col(p.ci), fontSize: 12, fontWeight: 600 }),
        Plot.tip(vis, Plot.pointer({ x: 'x', y: 'v', title: (p: any) => `Learning rate ${p.eta}, ${p.k} trees${budget ? ` (budget ${(p.k * p.eta).toFixed(1)})` : ''}\nHeld-out RMSE: $${p.v.toFixed(2)}bn${p.zone ? '\nIn the good zone (within 5% of its best)' : ''}` })),
      ],
    }));
  }
  $effect(() => { curves; xmode; draw(); });
  $effect(() => { depth; compute(); });
</script>

<Explorable title="Halve the learning rate and you need about twice the trees; small steps also leave a wider safe zone" caption="Gradient boosting on the real retail-sales table (trained 1993 to 2022) at four learning rates. Each line is the <b>held-out</b> error on January 2023 to September 2026 as trees are added; the thick dotted stretch is each rate's <b>good zone</b>, every tree count within 5% of its lowest error, and the big dot is the lowest point. Switch the x-axis to <b>Trees × learning rate</b>: the curves for 0.05, 0.1 and 0.3 nearly land on top of each other. With no trees, every curve starts at $49.4bn (off the chart). In real tuning you would read these curves on rolling folds, never on the test months; here they are shown for teaching. Data: FRED RSXFSN, NSA, $ billions.">
  {#snippet controls()}
    <span class="grp"><span class="lab" id="lb-d">Tree depth</span>
      <span class="seg" role="group" aria-labelledby="lb-d">{#each DEPTHS as dd}<button class:on={depth === dd} aria-pressed={depth === dd} onclick={() => (depth = dd)}>{dd}</button>{/each}</span></span>
    <span class="grp"><span class="lab" id="lb-x">x-axis</span>
      <span class="seg" role="group" aria-labelledby="lb-x">
        <button class:on={xmode === 'trees'} aria-pressed={xmode === 'trees'} onclick={() => (xmode = 'trees')}>Number of trees</button>
        <button class:on={xmode === 'budget'} aria-pressed={xmode === 'budget'} onclick={() => (xmode = 'budget')}>Trees × learning rate</button>
      </span></span>
  {/snippet}
  {#snippet aside()}
    <div class="side" aria-live="polite">
      {#if curves}
        <table>
          <caption>Depth-{depth} trees, held-out RMSE ($bn)</caption>
          <thead><tr><th scope="col">Rate</th><th scope="col">Lowest</th><th scope="col">at trees</th><th scope="col">Good zone</th></tr></thead>
          <tbody>
            {#each curves as c, i}
              <tr><th scope="row"><span class="sw" style={`background:${col(i)}`}></span>{c.eta}</th><td>${c.min.toFixed(1)}</td><td>{c.best}</td>
                <td>{c.last >= MAXR ? `${c.first}–${MAXR}+` : `${c.first}–${c.last}`}</td></tr>
            {/each}
          </tbody>
        </table>
        <p class="note">Rate 1 memorizes the training years (training RMSE <b>${curves[3].train300.toFixed(2)}bn</b> after {MAXR} trees) and its good zone spans just <b>{curves[3].count}</b> tree counts. Rate 0.1 stays within 5% of its best for <b>{curves[1].count}</b> tree counts.</p>
      {:else}<p class="note">Growing {ETAS.length * MAXR} trees…</p>{/if}
    </div>
  {/snippet}
  <div class="wrap">
    {#if busy}<div class="busy" role="status">Growing {ETAS.length * MAXR} trees…</div>{/if}
    <div bind:this={el} class="chart"></div>
  </div>
</Explorable>

<style>
  .wrap { position: relative; }
  .chart { min-height: 280px; }
  .busy { position: absolute; top: .4rem; right: .4rem; font-size: .8rem; color: var(--muted); background: var(--surface-2); padding: .2rem .6rem; border-radius: 6px; z-index: 2; }
  .grp { display: inline-flex; align-items: center; gap: .5rem; flex-wrap: wrap; }
  .lab { font-size: .82rem; }
  .side { font-size: .84rem; color: var(--text-2); }
  table { width: 100%; border-collapse: collapse; font-size: .8rem; margin: 0 0 .7rem; }
  caption { text-align: left; font-size: .78rem; font-weight: 650; color: var(--muted); padding-bottom: .3rem; }
  th, td { padding: .25rem .3rem; border-bottom: 1px solid var(--border); text-align: right; font-variant-numeric: tabular-nums; }
  th[scope='row'], thead th:first-child { text-align: left; white-space: nowrap; }
  thead th { color: var(--muted); font-weight: 600; }
  td { color: var(--text); }
  .sw { display: inline-block; width: 10px; height: 10px; border-radius: 2px; margin-right: .35rem; vertical-align: -1px; }
  .note { margin: 0; line-height: 1.5; font-size: .8rem; }
  .note b { color: var(--text); font-variant-numeric: tabular-nums; }
</style>
