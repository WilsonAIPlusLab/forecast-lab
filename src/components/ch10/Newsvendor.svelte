<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, rng, ym } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { fitETS, simulate, quantile, expectedCost } from './models';

  // Newsvendor: turn a simulated demand distribution for December into a stocking decision.
  let cu = $state(0.6), co = $state(0.25);
  let D: number[] = $state.raw([]);
  let target: Date | null = $state(null);
  let elH: HTMLDivElement, elC: HTMLDivElement;
  const fmtM = (v: number) => Math.round(v).toLocaleString('en-US');

  async function load() {
    const s = await loadSeries('MRTSSM448USN', { start: '2022-01-01' });
    const last = s.data[s.data.length - 1].date;
    let tYear = last.getFullYear(); if (last.getMonth() === 11) tYear += 1;
    const h = (tYear - last.getFullYear()) * 12 + (11 - last.getMonth());
    target = new Date(tYear, 11, 1);
    const fit = fitETS(s.data.map((p) => Math.log(p.value)), { m: 12, trend: true, season: true });
    const r = rng(11);
    D = Array.from({ length: 4000 }, () => Math.exp(simulate(fit, h, r.u, fit.resid)[h - 1]));
  }

  const res = $derived.by(() => {
    if (!D.length) return null;
    const cr = cu / (cu + co);
    const Q = quantile(D, cr), med = quantile(D, 0.5), mean = D.reduce((a, b) => a + b, 0) / D.length;
    const lo = quantile(D, 0.005), hi = quantile(D, 0.995);
    const grid = Array.from({ length: 121 }, (_, i) => lo + ((hi - lo) * i) / 120);
    const curve = grid.map((q) => ({ q, c: expectedCost(D, q, cu, co) }));
    return { cr, Q, med, mean, lo, hi, curve, cQ: expectedCost(D, Q, cu, co), cMean: expectedCost(D, mean, cu, co) };
  });

  function draw() {
    if (!elH || !res) return;
    const W = elH.clientWidth;
    const pts = D.filter((d) => d >= res.lo && d <= res.hi).map((x) => ({ x, covered: x <= res.Q }));
    const lab = (x: number, t: string, i: number) => Plot.text([{ x }], { x: 'x', frameAnchor: 'top', dy: -16 + i * 14, text: () => t, textAnchor: i ? 'start' : 'end', dx: i ? 6 : -6, fill: C.text, fontSize: 12, fontWeight: 600, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' } as any);
    elH.replaceChildren(Plot.plot({
      width: W, height: 230, marginLeft: 44, marginRight: 16, marginTop: 34, style: plotStyle(),
      x: { label: `December ${target?.getFullYear()} demand ($ millions) →`, domain: [res.lo, res.hi], tickFormat: (d: number) => fmtM(d) }, y: { grid: true, label: '↑ Simulated Decembers', ticks: 4 },
      color: { domain: [true, false], range: [C.s[2], C.s[1]] },
      marks: [
        Plot.rectY(pts, Plot.binX({ y: 'count' }, { x: 'x', fill: 'covered', thresholds: 50, insetLeft: 0.5, insetRight: 0.5, fillOpacity: 0.75 } as any)),
        Plot.ruleY([0], { stroke: C.borderStrong }),
        Plot.ruleX([res.mean], { stroke: C.muted, strokeWidth: 2, strokeDasharray: '4,4' }),
        Plot.ruleX([res.Q], { stroke: C.forecast, strokeWidth: 3 }),
        lab(res.mean, 'Point forecast', res.Q >= res.mean ? 0 : 1),
        lab(res.Q, `Stock (${Math.round(res.cr * 100)}th pct.)`, res.Q >= res.mean ? 1 : 0),
      ],
    }));
    const best = res.curve.reduce((a, b) => (b.c < a.c ? b : a));
    elC.replaceChildren(Plot.plot({
      width: W, height: 190, marginLeft: 44, marginRight: 16, marginTop: 14, style: plotStyle(),
      x: { label: 'Stock level ($ millions) →', domain: [res.lo, res.hi], tickFormat: (d: number) => fmtM(d) }, y: { grid: true, label: '↑ Expected cost ($ millions)', zero: true },
      marks: [
        Plot.lineY(res.curve, { x: 'q', y: 'c', stroke: C.s[0], strokeWidth: 2.4 }),
        Plot.dot([{ q: res.mean, c: res.cMean }], { x: 'q', y: 'c', r: 5, fill: C.surface, stroke: C.muted, strokeWidth: 2 }),
        Plot.dot([{ q: res.Q, c: res.cQ }], { x: 'q', y: 'c', r: 6, fill: C.forecast, stroke: C.surface, strokeWidth: 1.5 }),
        Plot.text([best], { x: 'q', y: 'c', text: () => 'lowest expected cost', dy: 16, fill: C.text2, fontSize: 12 }),
        Plot.tip(res.curve, Plot.pointerX({ x: 'q', y: 'c', title: (r: any) => `Stock $${fmtM(r.q)} million\nExpected cost: $${fmtM(r.c)} million` })),
      ],
    }));
  }

  $effect(() => { res; draw(); });
  onMount(() => { load(); return watchLayout(elH, draw); });
</script>

<Explorable title="The newsvendor: let the costs of being wrong pick your quantile"
  caption="The histogram shows 4,000 simulated values of December sales for U.S. clothing stores (MRTSSM448USN, $ millions, NSA), from an exponential smoothing model on log sales fitted to January 2022 onward (after the pandemic swings). The cost sliders are assumptions, per $1 of retail value: <b>understock</b> is the margin lost on a sale you could not make; <b>overstock</b> is the markdown and holding cost of a leftover dollar of stock. Green bars are the Decembers your stock would fully cover; pink bars are Decembers when you would run out. The lower chart computes expected cost for every stock level by averaging over the simulations.">
  {#snippet controls()}
    <label class="sl">Understock cost <input type="range" min="0.05" max="1" step="0.05" bind:value={cu} aria-valuetext={`${cu.toFixed(2)} dollars per dollar of lost sales`} /> <b>${cu.toFixed(2)}</b></label>
    <label class="sl">Overstock cost <input type="range" min="0.05" max="1" step="0.05" bind:value={co} aria-valuetext={`${co.toFixed(2)} dollars per dollar of leftover stock`} /> <b>${co.toFixed(2)}</b></label>
  {/snippet}
  {#snippet aside()}
    {#if res && target}
      <div class="rec" aria-live="polite">
        <div class="eyebrow">Recommendation</div>
        <p class="big">Stock <b>${fmtM(res.Q)} million</b> for {ym(target)}.</p>
        <p>Critical ratio {cu.toFixed(2)} / ({cu.toFixed(2)} + {co.toFixed(2)}) = <b>{res.cr.toFixed(2)}</b>: this covers demand in {Math.round(res.cr * 100)}% of simulated Decembers.</p>
        <p>That is <b>${fmtM(Math.abs(res.Q - res.mean))} million {res.Q >= res.mean ? 'above' : 'below'}</b> the point forecast. Expected cost: ${fmtM(res.cQ)} million, against ${fmtM(res.cMean)} million if you stocked the point forecast.</p>
        {#if res.cr < 0.5}<p class="note">Leftovers cost more than shortages here, so the best plan stocks <i>below</i> the forecast.</p>{/if}
      </div>
    {/if}
  {/snippet}
  <div bind:this={elH} role="img" aria-label="Histogram of simulated December demand with the optimal stock level"></div>
  <div bind:this={elC} role="img" aria-label="Expected cost against stock level, lowest at the optimal stock"></div>
</Explorable>

<style>
  .rec { font-size: .86rem; color: var(--text-2); display: grid; gap: .5rem; }
  .rec p { margin: 0; }
  .rec b { color: var(--text); font-variant-numeric: tabular-nums; }
  .big { font-size: 1.05rem; color: var(--text); }
  .note { color: var(--accent-text); }
</style>
