<script lang="ts">
  // Lag wobble: why we rarely read VAR coefficients one by one.
  // Drag the lag length from 1 to 8. Left: the unemployment equation's coefficients on past funds rates
  // (95% intervals) flip sign and are mostly insignificant. Right: the impulse response that combines
  // all of them barely changes once p >= 2. Precomputed in src/labs/ch09/make_data.R.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import raw from './var_extra.json';
  import { col } from './varlib';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';

  type Lag = { p: number; n: number; est: number[] | number; se: number[] | number; pval: number[] | number; sum: number; joint_p: number; aic: number; bic: number; root: number; irf: { pt: number[]; lo: number[]; hi: number[] } };
  const arr = (x: number[] | number) => (Array.isArray(x) ? x : [x]);
  const L = ((raw as any).lags as Lag[]).map((d) => ({ ...d, est: arr(d.est), se: arr(d.se), pval: arr(d.pval) }));
  const best = (key: 'aic' | 'bic') => L.reduce((a, b) => (b[key] < a[key] ? b : a)).p;
  const AIC = best('aic'), BIC = best('bic');
  const Z95 = 1.96; // 95% interval: a whisker that crosses zero = not significant at 5%

  let p = $state(4);
  let elC: HTMLDivElement, elI: HTMLDivElement;
  const d = $derived(L[p - 1]);
  const nsig = $derived(d.pval.filter((v) => v < 0.05).length);
  const signs = $derived(new Set(d.est.map((v) => Math.sign(v))).size > 1);
  const peakQ = $derived(d.irf.pt.reduce((j, v, i, a) => (v > a[j] ? i : j), 0));
  const cmax = Math.max(...L.flatMap((x) => x.est.map((e, i) => Math.abs(e) + Z95 * x.se[i])));
  const imax = Math.max(...L.flatMap((x) => [...x.irf.hi, -Math.min(...x.irf.lo)]));
  const f = (v: number, dg = 3) => (v > 0 ? '+' : v < 0 ? '−' : '') + Math.abs(v).toFixed(dg);

  function drawCoef() {
    if (!elC) return;
    const W = elC.clientWidth;
    const rows = d.est.map((e, i) => ({ lag: i + 1, e, lo: e - Z95 * d.se[i], hi: e + Z95 * d.se[i], sig: d.pval[i] < 0.05 }));
    elC.replaceChildren(Plot.plot({
      width: W, height: 270, marginLeft: 52, marginBottom: 38, style: plotStyle(),
      x: { domain: [0.5, 8.5], ticks: [1, 2, 3, 4, 5, 6, 7, 8], label: 'lag of the funds rate (quarters)', labelAnchor: 'right' },
      y: { domain: [-cmax, cmax], grid: true, label: 'coefficient (pp per pp)', tickFormat: (v: number) => (v > 0 ? '+' : '') + v },
      ariaLabel: `Coefficients on ${p} lags of the funds rate in the unemployment equation, with 95% intervals`,
      marks: [
        Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
        Plot.ruleX(rows, { x: 'lag', y1: 'lo', y2: 'hi', stroke: col('ffr'), strokeWidth: 2.5, strokeOpacity: 0.7 }),
        Plot.dot(rows, { x: 'lag', y: 'e', r: 5.5, fill: (r: any) => (r.sig ? col('ffr') : C.surface), stroke: col('ffr'), strokeWidth: 2 }),
        Plot.tip(rows, Plot.pointerX({ x: 'lag', y: 'e', title: (r: any) => `Funds rate, lag ${r.lag}\nCoefficient ${f(r.e)}\n95% interval ${f(r.lo)} to ${f(r.hi)}\n${r.sig ? 'significant at 5%' : 'not significant at 5%'}` })),
      ],
    }));
  }
  function drawIrf() {
    if (!elI) return;
    const W = elI.clientWidth;
    const ctx = L.filter((x) => x.p !== p).flatMap((x) => x.irf.pt.map((v, h) => ({ h, v, p: x.p })));
    const rows = d.irf.pt.map((v, h) => ({ h, v, lo: d.irf.lo[h], hi: d.irf.hi[h] }));
    const c = col('unemp');
    elI.replaceChildren(Plot.plot({
      width: W, height: 270, marginLeft: 52, marginBottom: 38, marginRight: 14, style: plotStyle(),
      x: { domain: [0, 20], ticks: [0, 4, 8, 12, 16, 20], label: 'quarters after the hike', labelAnchor: 'right' },
      y: { domain: [-0.1, imax], grid: true, label: 'unemployment, pp vs. no hike', tickFormat: (v: number) => (v > 0 ? '+' : '') + v },
      ariaLabel: `Response of unemployment to a one-standard-deviation funds-rate shock in a VAR(${p}), with 90% band; faint lines show the other lag lengths`,
      marks: [
        Plot.areaY(rows, { x: 'h', y1: 'lo', y2: 'hi', fill: c, fillOpacity: 0.18, curve: 'monotone-x' }),
        Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
        Plot.lineY(ctx, { x: 'h', y: 'v', z: 'p', stroke: C.muted, strokeOpacity: 0.4, strokeWidth: 1.25, curve: 'monotone-x' }),
        Plot.lineY(rows, { x: 'h', y: 'v', stroke: c, strokeWidth: 3, curve: 'monotone-x' }),
        Plot.text([rows[20]], { x: 'h', y: 'v', text: () => `VAR(${p})`, dy: -10, textAnchor: 'end', fill: c, fontWeight: 650, fontSize: 12 }),
        Plot.tip(rows, Plot.pointerX({ x: 'h', y: 'v', title: (r: any) => `Quarter ${r.h}\nUnemployment ${f(r.v)} pp\n90% band ${f(r.lo)} to ${f(r.hi)} pp` })),
      ],
    }));
  }
  $effect(() => { p; drawCoef(); drawIrf(); });
  onMount(() => { const a = watchLayout(elC, drawCoef); const b = watchLayout(elI, drawIrf); return () => { a(); b(); }; });
</script>

<Explorable title="Coefficients wobble, the response holds: read the IRF, not the table"
  caption={`Drag the number of lags in the VAR. Left: the unemployment equation's coefficients on past funds rates, with 95% intervals (filled dot = significant at 5%, so its interval clears zero). They flip sign from lag to lag and change every time you add a lag. Right: the impulse response that combines all 3 × p + 1 coefficients of all three equations, with its 90% bootstrap band; faint lines are the other lag lengths. Funds-rate shock of one standard deviation, baseline ordering, 1960Q1–2000Q4. Data: FRED (CPIAUCSL, UNRATE, FEDFUNDS).`}>
  {#snippet controls()}
    <label class="sl">Lags <i>p</i> <input type="range" min="1" max="8" bind:value={p} aria-valuetext={`VAR with ${p} lags`} /> <b>{p}</b></label>
  {/snippet}
  {#snippet aside()}
    <div class="ro" aria-live="polite">
      <div class="lbl">VAR({p}): {3 * p + 1} coefficients per equation, {d.n} quarters</div>
      <dl>
        <dt>Funds-rate lags significant alone (5%)</dt><dd><b>{nsig} of {p}</b></dd>
        <dt>All {p} lags together (F-test p)</dt><dd><b>{d.joint_p < 0.001 ? '< 0.001' : d.joint_p.toFixed(3)}</b></dd>
        <dt>Sum of the {p} coefficients</dt><dd><b>{f(d.sum)}</b></dd>
        <dt>Unemployment response after 8 q</dt><dd><b>{f(d.irf.pt[8], 2)} pp</b></dd>
        <dt>Peak of the response</dt><dd><b>quarter {peakQ}</b></dd>
        <dt>Largest root (stable if &lt; 1)</dt><dd><b>{d.root.toFixed(2)}</b></dd>
      </dl>
      <p class="sum">
        {#if p === 1}One lag cannot turn around: the response just keeps climbing. AIC and BIC both prefer 3 lags to 1.{:else if signs}Signs flip from lag to lag{nsig === 0 ? ', and none is significant alone' : ''}, yet the lags matter <i>together</i> and the response keeps the same hump.{:else}Every coefficient has the same sign here, but the response is still the thing to report.{/if}
        {#if p === AIC && p === BIC} AIC and BIC both pick this lag length.{:else if p === AIC} AIC picks this lag length.{:else if p === BIC} BIC picks this lag length.{/if}
      </p>
    </div>
  {/snippet}
  <div class="two">
    <figure><figcaption>The table: unemployment equation, funds-rate lags</figcaption><div bind:this={elC} class="chart"></div></figure>
    <figure><figcaption>The story: unemployment after a surprise hike</figcaption><div bind:this={elI} class="chart"></div></figure>
  </div>
</Explorable>

<style>
  .two { display: grid; grid-template-columns: 1fr 1fr; gap: 1.2rem; }
  @media (max-width: 760px) { .two { grid-template-columns: 1fr; } }
  figure { margin: 0; min-width: 0; }
  figcaption { font-size: .8rem; font-weight: 650; color: var(--text-2); margin-bottom: .25rem; }
  .chart { min-height: 270px; }
  .ro { font-size: .82rem; }
  .lbl { font-size: .75rem; color: var(--muted); font-weight: 650; margin-bottom: .5rem; }
  dl { display: grid; grid-template-columns: 1fr auto; gap: .3rem .7rem; margin: 0; font-variant-numeric: tabular-nums; }
  dt { color: var(--text-2); }
  dd { margin: 0; text-align: right; color: var(--text); }
  .sum { color: var(--text-2); margin: .8rem 0 0; line-height: 1.45; }
</style>
