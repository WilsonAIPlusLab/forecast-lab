<script lang="ts">
  // Signature explorable 4: press "difference" and watch a trending series (and its ACF) become stationary.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, ym, type Pt } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { sampleAcf } from './arma';

  const SERIES = {
    pce: { label: 'Core PCE prices', id: 'PCEPILFE', start: '2000-01-01', end: undefined, log: true, unit: 'log index',
      r: 'In R, <code>ndiffs()</code> asks for 2 differences of log core PCE since 2000 (KPSS), while the ADF version asks for 1. Is inflation itself stationary? That is the judgment call this chapter turns on.' },
    retail: { label: 'Retail sales (NSA)', id: 'RSXFSN', start: '2010-01-01', end: '2019-12-01', log: true, unit: 'log $ millions',
      r: 'In R, <code>nsdiffs()</code> = 1 and then <code>ndiffs()</code> = 1 for log retail sales, 2010–2019: one seasonal and one regular difference, the recipe of the classic "airline" model ARIMA(0,1,1)(0,1,1)[12].' },
    unrate: { label: 'Unemployment rate', id: 'UNRATE', start: '1990-01-01', end: '2019-12-01', log: false, unit: '%',
      r: 'In R, <code>ndiffs()</code> = 1 for the unemployment rate, 1990–2019. Difference it twice and the lag-1 autocorrelation drops to −0.57: a textbook case of over-differencing.' },
  } as const;
  type K = keyof typeof SERIES;

  let sid: K = $state('pce');
  let ops: (1 | 12)[] = $state([]);
  let raw: Pt[] = $state([]);
  let seriesEl: HTMLDivElement, acfEl: HTMLDivElement, wrap: HTMLDivElement;
  const LAGS = 36;

  async function load() {
    const s = SERIES[sid];
    const d = await loadSeries(s.id, { start: s.start, end: s.end });
    raw = d.data.map((p) => ({ date: p.date, value: s.log ? Math.log(p.value) : p.value }));
  }
  $effect(() => { sid; ops = []; load(); });

  const cur = $derived.by(() => {
    let x = raw;
    for (const k of ops) x = x.slice(k).map((p, i) => ({ date: p.date, value: p.value - x[i].value }));
    return x;
  });
  const rho = $derived(cur.length > LAGS + 10 ? sampleAcf(cur.map((p) => p.value), LAGS) : []);
  const label = $derived([SERIES[sid].log ? `log(${SERIES[sid].label})` : SERIES[sid].label, ...ops.map((k) => (k === 1 ? 'Δ' : 'Δ₁₂'))].join('  →  '));

  const diagnosis = $derived.by(() => {
    if (!rho.length) return { tone: '', text: '' };
    const r1 = rho[0], r12 = rho[11], r24 = rho[23];
    if (r1 > 0.8 && r12 > 0.5) return { tone: 'warn', text: `Still trending. The ACF is ${r1.toFixed(2)} at lag 1 and ${r12.toFixed(2)} at lag 12, fading very slowly: the signature of a unit root. Try a difference.` };
    if (r12 > 0.45 && r24 > 0.3) return { tone: 'warn', text: `Seasonal spikes: the ACF is ${r12.toFixed(2)} at lag 12 and ${r24.toFixed(2)} at lag 24, decaying slowly year after year. Try a seasonal difference (Δ₁₂).` };
    if (r1 < -0.4) return { tone: 'bad', text: `A big negative spike at lag 1 (${r1.toFixed(2)}). Differencing a series that was already stationary produces exactly this, so treat it as a warning of over-differencing. It can also be a genuine MA(1) term: the airline model for retail sales and the IMA model for inflation both have one. Compare with the previous step before deciding.` };
    if (r1 > 0.3) return { tone: 'warn', text: `Borderline. The autocorrelation is still ${r1.toFixed(2)} at lag 1 (and ${r12.toFixed(2)} at lag 12), so shocks linger for a while. Unit-root tests often disagree on series like this: another difference is defensible, and so is stopping here and letting AR terms soak up the persistence.` };
    return { tone: 'good', text: `Looks stationary: autocorrelations die out quickly (lag 1: ${r1.toFixed(2)}, lag 12: ${r12.toFixed(2)}). What remains is short-lived structure for AR and MA terms to model.` };
  });

  function draw() {
    if (!seriesEl || !acfEl || !cur.length) return;
    const unit = ops.length ? 'change' : SERIES[sid].unit;
    const c1 = Plot.plot({
      width: seriesEl.clientWidth, height: 230, marginLeft: 52, marginTop: 10, marginBottom: 28,
      style: plotStyle(), x: { label: null }, y: { label: null, grid: true, ticks: 5 },
      marks: [
        ...(ops.length ? [Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 })] : []),
        Plot.lineY(cur, { x: 'date', y: 'value', stroke: ops.length ? C.fitted : C.history, strokeWidth: 1.6 }),
        Plot.tip(cur, Plot.pointerX({ x: 'date', y: 'value', title: (p: any) => `${ym(p.date)}\n${p.value.toFixed(4)} (${unit})` })),
      ],
    });
    c1.setAttribute('aria-label', `${label}, ${cur.length} monthly observations`);
    seriesEl.replaceChildren(c1);
    const ci = 1.96 / Math.sqrt(cur.length);
    const d = rho.map((v, i) => ({ lag: i + 1, v, sig: Math.abs(v) > ci }));
    const c2 = Plot.plot({
      width: acfEl.clientWidth, height: 230, marginLeft: 36, marginTop: 10, marginBottom: 32,
      style: plotStyle(), x: { label: 'lag (months)', domain: [0.5, LAGS + 0.5], ticks: [1, 6, 12, 18, 24, 30, 36] }, y: { label: 'ACF', domain: [-1, 1], grid: true, ticks: 5 },
      marks: [
        Plot.areaY([{ l: 0.5 }, { l: LAGS + 0.5 }], { x: 'l', y1: -ci, y2: ci, fill: C.muted, fillOpacity: 0.12 }),
        Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
        Plot.ruleX(d, { x: 'lag', y1: 0, y2: 'v', stroke: (r: any) => (r.sig ? C.s[0] : C.muted), strokeWidth: 2 }),
        Plot.dot(d, { x: 'lag', y: 'v', fill: (r: any) => (r.sig ? C.s[0] : C.muted), r: 3 }),
        Plot.tip(d, Plot.pointerX({ x: 'lag', y: 'v', title: (r: any) => `Lag ${r.lag}: ${r.v.toFixed(3)}${r.sig ? ' (outside the band)' : ''}` })),
      ],
    });
    c2.setAttribute('aria-label', `Autocorrelation function of ${label}`);
    acfEl.replaceChildren(c2);
  }

  let animate = false;
  function push(k: 1 | 12) { if (ops.length < 3) { ops = [...ops, k]; animate = true; } }
  function undo() { ops = ops.slice(0, -1); animate = true; }

  $effect(() => {
    cur; rho; draw();
    if (animate && wrap && !matchMedia('(prefers-reduced-motion: reduce)').matches) wrap.animate([{ opacity: 0.25 }, { opacity: 1 }], { duration: 350, easing: 'cubic-bezier(0.2,0,0,1)' });
    animate = false;
  });
  onMount(() => {
    const offs = [seriesEl, acfEl].map((e) => watchLayout(e, draw));
    return () => offs.forEach((f) => f());
  });
</script>

<Explorable title="The differencing machine" caption="Choose a series, then press a difference button. Δ replaces each value with its change from the month before; Δ₁₂ with its change from the same month a year earlier. Watch the ACF on the right: a slow, straight-line decay means a trend is still there; spikes at 12, 24, 36 mean seasonality; a single big negative spike at lag 1 means you went one difference too far.">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Series">
      {#each Object.entries(SERIES) as [k, v]}<button class:on={sid === k} onclick={() => (sid = k as K)}>{v.label}</button>{/each}
    </div>
    <div class="ops" role="group" aria-label="Transformations">
      <button class="btn btn-sm btn-primary" onclick={() => push(1)} disabled={ops.length >= 3}>Difference Δ</button>
      <button class="btn btn-sm" onclick={() => push(12)} disabled={ops.length >= 3}>Seasonal Δ₁₂</button>
      <button class="btn btn-sm btn-ghost" onclick={undo} disabled={!ops.length}>Undo</button>
    </div>
  {/snippet}
  <div class="chain" aria-live="polite">{label}</div>
  <div class="pair" bind:this={wrap}>
    <div bind:this={seriesEl} class="c"></div>
    <div bind:this={acfEl} class="c"></div>
  </div>
  {#if diagnosis.text}<p class="diag {diagnosis.tone}" aria-live="polite">{diagnosis.text}</p>{/if}
  <p class="rnote">{@html SERIES[sid].r}</p>
</Explorable>

<style>
  .ops { display: inline-flex; gap: .4rem; }
  .chain { font: 600 .9rem var(--font-mono); color: var(--text); margin-bottom: .5rem; }
  .pair { display: grid; grid-template-columns: minmax(0, 1.25fr) minmax(0, 1fr); gap: 1.2rem; }
  @media (max-width: 760px) { .pair { grid-template-columns: 1fr; } }
  .c { min-height: 230px; }
  .diag { margin: .8rem 0 .3rem; padding: .6rem .8rem; border-radius: 8px; border: 1px solid var(--border); font-size: .88rem; color: var(--text); }
  .diag.warn { border-color: color-mix(in srgb, var(--c-actual) 50%, transparent); }
  .diag.bad { border-color: color-mix(in srgb, var(--danger) 50%, transparent); }
  .diag.good { border-color: color-mix(in srgb, var(--good) 50%, transparent); }
  .rnote { font-size: .82rem; color: var(--muted); margin: .4rem 0 0; }
</style>
