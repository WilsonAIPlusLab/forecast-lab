<script lang="ts">
  // Cointegration leash: two yields wander, but GS10 − β·TB3MS stays on a leash for β near 1.
  // ADF statistic computed live in JS (adf.ts reproduces urca::ur.df(type = "drift", lags = 4)).
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { adfTau } from './adf';
  import { col } from './varlib';

  let beta = $state(0);
  let g: { date: Date; value: number }[] = $state([]);
  let tb: number[] = $state([]);
  let curve: { b: number; tau: number }[] = $state([]);
  let el: HTMLDivElement, el2: HTMLDivElement;
  const DF = -2.86, EG = -3.34;
  const PRESETS = [
    { b: 0, l: '0: the 10-year alone' },
    { b: 0.84, l: '0.84: Engle–Granger' },
    { b: 0.99, l: '0.99: Johansen' },
    { b: 1, l: '1: the spread' },
  ];

  async function load() {
    const [a, b] = await Promise.all([loadSeries('GS10', { start: '1960-01-01', end: '2019-12-01' }), loadSeries('TB3MS', { start: '1960-01-01', end: '2019-12-01' })]);
    const m = new Map(b.data.map((p) => [+p.date, p.value]));
    const rows = a.data.filter((p) => m.has(+p.date));
    g = rows; tb = rows.map((p) => m.get(+p.date)!);
    const yv = rows.map((p) => p.value);
    curve = Array.from({ length: 101 }, (_, i) => { const bb = i * 0.02; return { b: bb, tau: adfTau(yv.map((v, j) => v - bb * tb[j])) }; });
  }
  onMount(() => { load(); return watchLayout(el, draw); });

  const z = $derived(g.map((p, i) => p.value - beta * tb[i]));
  const mu = $derived(z.length ? z.reduce((s, v) => s + v, 0) / z.length : 0);
  const sd = $derived(z.length ? Math.sqrt(z.reduce((s, v) => s + (v - mu) ** 2, 0) / (z.length - 1)) : 0);
  const tau = $derived(z.length ? adfTau(z) : 0);
  const verdict = $derived(tau < EG ? 'stationary: rejects a unit root even against the stricter Engle–Granger value' : tau < DF ? 'stationary for a β fixed in advance (rejects at 5%)' : 'not stationary: cannot reject a unit root');

  function draw() {
    if (!el || !g.length) return;
    const W = el.clientWidth;
    const top = [...g.map((p) => ({ date: p.date, v: p.value, k: '10-year' })), ...g.map((p, i) => ({ date: p.date, v: tb[i], k: '3-month' }))];
    const c10 = C.s[3], c3 = C.s[4];
    const zr = g.map((p, i) => ({ date: p.date, v: z[i] - mu }));
    const lim = Math.max(8, ...zr.map((d) => Math.abs(d.v)));
    el.replaceChildren(
      Plot.plot({
        width: W, height: 170, marginLeft: 40, marginRight: 70, marginTop: 8, marginBottom: 20, style: plotStyle(),
        x: { label: null }, y: { grid: true, label: '%', ticks: 4 }, ariaLabel: '10-year and 3-month Treasury yields, 1960 to 2019',
        marks: [
          Plot.lineY(top, { x: 'date', y: 'v', z: 'k', stroke: (d: any) => (d.k === '10-year' ? c10 : c3), strokeWidth: 1.6 }),
          Plot.text(top.filter((d) => d.k === '10-year'), Plot.selectLast({ x: 'date', y: 'v', text: 'k', dx: 6, dy: -8, textAnchor: 'start', fill: c10, fontWeight: 650, fontSize: 12 })),
          Plot.text(top.filter((d) => d.k === '3-month'), Plot.selectLast({ x: 'date', y: 'v', text: 'k', dx: 6, dy: 8, textAnchor: 'start', fill: c3, fontWeight: 650, fontSize: 12 })),
        ],
      }),
      Plot.plot({
        width: W, height: 190, marginLeft: 40, marginRight: 70, marginTop: 14, marginBottom: 28, style: plotStyle(),
        x: { label: null }, y: { grid: true, domain: [-lim, lim], label: `GS10 − ${beta.toFixed(2)}·TB3MS, minus its mean (pp)`, ticks: 5 },
        ariaLabel: `The combination GS10 minus ${beta.toFixed(2)} times TB3MS, demeaned`,
        marks: [
          Plot.areaY(zr, { x: 'date', y1: 0, y2: 'v', fill: col('spread'), fillOpacity: 0.22 }),
          Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
          Plot.lineY(zr, { x: 'date', y: 'v', stroke: col('spread'), strokeWidth: 1.6 }),
          Plot.tip(zr, Plot.pointerX({ x: 'date', y: 'v', title: (d: any) => `${d.date.toISOString().slice(0, 7)}\n${d.v >= 0 ? '+' : ''}${d.v.toFixed(2)} pp from its mean` })),
        ],
      }),
    );
    if (!el2 || !curve.length) return;
    el2.replaceChildren(Plot.plot({
      width: el2.clientWidth || 260, height: 190, marginLeft: 38, marginRight: 8, marginBottom: 32, style: plotStyle(),
      x: { label: 'β', domain: [0, 2] }, y: { label: 'ADF τ', domain: [-4.5, -0.5], grid: true, ticks: 4 },
      ariaLabel: 'ADF statistic as a function of beta',
      marks: [
        Plot.ruleY([DF], { stroke: C.muted, strokeDasharray: '4,4', strokeWidth: 1.5 }),
        Plot.ruleY([EG], { stroke: C.danger, strokeDasharray: '4,4', strokeWidth: 1.5 }),
        Plot.text([{ y: DF, t: '−2.86 (β fixed)' }, { y: EG, t: '−3.34 (β estimated)' }], { x: 2, y: 'y', text: 't', textAnchor: 'end', dy: -6, fill: (d: any) => (d.y === EG ? C.danger : C.muted), fontSize: 12, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
        Plot.lineY(curve, { x: 'b', y: 'tau', stroke: C.text2, strokeWidth: 2 }),
        Plot.dot([{ b: beta, tau }], { x: 'b', y: 'tau', r: 6, fill: col('spread'), stroke: C.surface, strokeWidth: 2 }),
      ],
    }));
  }
  $effect(() => { z; curve; draw(); });
</script>

<Explorable title="Two wandering yields, one leash: find the β that makes the gap stationary"
  caption={`Top: the 10-year Treasury yield (GS10) and the 3-month bill rate (TB3MS), monthly, 1960–2019, in percent. Bottom: the combination GS10 − β·TB3MS, centered on its mean. Drag β. At β = 0 you see the 10-year rate alone, wandering for decades. Near β = 1 the combination snaps back again and again: that is cointegration. The small chart tracks the augmented Dickey–Fuller statistic (constant, 4 lags) for every β; more negative = more clearly stationary. Use −2.86 for a β you fix in advance; when β is estimated from the same data, the stricter Engle–Granger value of −3.34 applies.`}>
  {#snippet controls()}
    <label class="sl">β <input type="range" min="0" max="2" step="0.01" bind:value={beta} aria-valuetext={`beta ${beta.toFixed(2)}`} /> <b>{beta.toFixed(2)}</b></label>
    <div class="seg" role="group" aria-label="Preset values of beta">
      {#each PRESETS as p}<button class:on={Math.abs(beta - p.b) < 1e-9} onclick={() => (beta = p.b)}>{p.l}</button>{/each}
    </div>
  {/snippet}
  {#snippet aside()}
    <div class="ro" aria-live="polite">
      <div class="lbl">ADF test on GS10 − {beta.toFixed(2)}·TB3MS</div>
      <div class="stat"><span class="stat-v">{tau.toFixed(2)}</span><span class="stat-l">τ statistic</span></div>
      <p class="v" class:ok={tau < DF}><b>{tau < DF ? 'On the leash.' : 'Wandering.'}</b> {verdict}.</p>
      <p class="sdv">Spread of the combination: s.d. {sd.toFixed(2)} pp</p>
      <div bind:this={el2} class="mini"></div>
    </div>
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 360px; }
  .ro { font-size: .82rem; }
  .lbl { font-size: .75rem; color: var(--muted); font-weight: 650; margin-bottom: .4rem; }
  .v { margin: .5rem 0 .3rem; color: var(--text-2); }
  .v.ok b { color: var(--good); }
  .sdv { color: var(--muted); font-size: .78rem; margin: 0 0 .4rem; font-variant-numeric: tabular-nums; }
  .mini { min-height: 190px; }
</style>
