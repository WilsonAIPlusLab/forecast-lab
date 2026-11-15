<script lang="ts">
  // Signature explorable 1: one dial (phi) moves a series from white noise to AR(1) to random walk to explosive.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { rng } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { ar1FcSd } from './arma';

  const N = 40;          // number of simulated futures
  const H = 60;          // months simulated
  const Y0 = 4;          // starting point: 4 units above the long-run mean
  const YLIM = 16;

  let phi = $state(0.8);
  let seed = $state(11);
  let el: HTMLDivElement;

  // Shocks depend only on the seed, so dragging phi morphs the same paths (direct manipulation).
  const shocks = $derived.by(() => {
    const r = rng(seed);
    return Array.from({ length: N }, () => Array.from({ length: H }, () => r.norm()));
  });

  const paths = $derived.by(() => shocks.map((e) => {
    const y = [Y0];
    for (let t = 1; t <= H; t++) y.push(phi * y[t - 1] + e[t - 1]);
    return y;
  }));

  const regime = $derived(phi < 0.995 ? 'stationary' : phi <= 1.005 ? 'unit' : 'explosive');
  const halfLife = $derived(phi <= 0 ? 0 : phi < 1 ? Math.log(0.5) / Math.log(phi) : Infinity);
  const band = (h: number) => 1.96 * ar1FcSd(phi, h);
  const longRun = $derived(phi < 1 ? 1.96 / Math.sqrt(1 - phi * phi) : Infinity);
  // How many of the 40 paths sit within +/-1 of the mean at month 60?
  const nearMean = $derived(paths.filter((p) => Math.abs(p[H]) <= 1).length);

  function draw() {
    if (!el) return;
    const W = el.clientWidth;
    const fan = Array.from({ length: H + 1 }, (_, h) => ({ h, m: Y0 * phi ** h, lo: Y0 * phi ** h - band(h), hi: Y0 * phi ** h + band(h) }));
    const rows = paths.flatMap((p, i) => p.map((v, h) => ({ h, v, i })));
    const hl = paths[0].map((v, h) => ({ h, v }));
    const clip = (v: number) => Math.max(-YLIM * 1.5, Math.min(YLIM * 1.5, v));
    const fanC = fan.map((d) => ({ ...d, lo: clip(d.lo), hi: clip(d.hi), m: clip(d.m) }));
    const last = fanC[H];
    const chart = Plot.plot({
      width: W, height: Math.max(300, Math.min(400, W * 0.5)), marginLeft: 44, marginRight: 96, marginTop: 16, marginBottom: 36,
      style: plotStyle(), clip: true,
      x: { label: 'months after the shock', domain: [0, H], ticks: 6 },
      y: { label: 'distance from long-run mean', domain: [-YLIM, YLIM], grid: true, ticks: 8 },
      marks: [
        Plot.areaY(fanC, { x: 'h', y1: 'lo', y2: 'hi', fill: C.forecast, fillOpacity: 0.16 }),
        Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5, strokeDasharray: '4 4' }),
        ...(phi < 1 ? [Plot.ruleY([-longRun, longRun], { stroke: C.fitted, strokeOpacity: 0.7, strokeDasharray: '2 4' })] : []),
        Plot.lineY(rows, { x: 'h', y: (d: any) => clip(d.v), z: 'i', stroke: C.history, strokeOpacity: 0.28, strokeWidth: 1.1 }),
        Plot.lineY(hl, { x: 'h', y: (d: any) => clip(d.v), stroke: C.actual, strokeWidth: 2.4 }),
        Plot.lineY(fanC, { x: 'h', y: 'm', stroke: C.forecast, strokeWidth: 3 }),
        Plot.dot([{ h: 0, v: Y0 }], { x: 'h', y: 'v', r: 5, fill: C.actual, stroke: C.surface, strokeWidth: 2 }),
        Plot.text([last], { x: 'h', y: (d: any) => Math.min(YLIM - 1, d.hi), text: () => '95% band', dx: 8, textAnchor: 'start', fill: C.forecast, fontSize: 12, fontWeight: 600 }),
        Plot.text([last], { x: 'h', y: 'm', text: () => 'forecast', dx: 8, textAnchor: 'start', fill: C.forecast, fontSize: 12 }),
        Plot.text([{ h: H, v: clip(paths[0][H]) }], { x: 'h', y: 'v', text: () => 'one future', dx: 8, dy: 12, textAnchor: 'start', fill: C.actual, fontSize: 12 }),
        ...(phi < 1 && longRun < YLIM ? [Plot.text([{ h: H, v: longRun }], { x: 'h', y: 'v', text: () => 'long-run range', dx: 8, dy: -8, textAnchor: 'start', fill: C.fitted, fontSize: 12 })] : []),
        Plot.tip(fanC, Plot.pointerX({ x: 'h', y: 'm', title: (d: any) => `Month ${d.h}\nForecast: ${d.m.toFixed(2)} units\n95% band: ${d.lo.toFixed(1)} to ${d.hi.toFixed(1)} units` })),
      ],
    });
    chart.setAttribute('aria-label', `Forty simulated AR(1) paths with phi = ${phi.toFixed(2)}, starting 4 units above the mean, with the forecast and its 95% band.`);
    el.replaceChildren(chart);
  }

  $effect(() => { paths; draw(); });
  onMount(() => watchLayout(el, draw));

  const f1 = (v: number) => (Number.isFinite(v) ? v.toFixed(1) : 'never');
</script>

<Explorable title="Turn the persistence dial: shocks either fade or pile up" caption={`Each grey line is one possible future of <i>y</i><sub>t</sub> = φ <i>y</i><sub>t−1</sub> + ε<sub>t</sub>, starting 4 units above its long-run mean with standard normal shocks. The gold line is one of them; the violet line and band are the forecast and its 95% interval made at month 0. Drag φ from 0 toward 1, then past it. All 40 paths use the same shocks at every φ, so you are watching persistence alone change.`}>
  {#snippet controls()}
    <label class="sl">Persistence φ
      <input type="range" min="0" max="1.05" step="0.01" bind:value={phi} list="phi-ticks"
        aria-label="Persistence phi" aria-valuetext={`phi equals ${phi.toFixed(2)}`} />
      <b>{phi.toFixed(2)}</b>
    </label>
    <datalist id="phi-ticks"><option value="0"></option><option value="0.5"></option><option value="0.9"></option><option value="1"></option></datalist>
    <div class="seg" role="group" aria-label="Presets">
      <button class:on={phi === 0} onclick={() => (phi = 0)}>White noise</button>
      <button class:on={phi === 0.9} onclick={() => (phi = 0.9)}>φ = 0.9</button>
      <button class:on={phi === 1} onclick={() => (phi = 1)}>Random walk</button>
    </div>
    <button class="btn btn-sm" onclick={() => (seed += 1)}>New shocks</button>
  {/snippet}
  {#snippet aside()}
    <div class="dial" aria-live="polite">
      <div class="regime {regime}">
        {#if regime === 'stationary'}Stationary: shocks fade{:else if regime === 'unit'}Unit root: shocks never fade{:else}Explosive: shocks grow{/if}
      </div>
      <div class="stat"><span class="stat-v">{f1(halfLife)}{Number.isFinite(halfLife) ? ' mo' : ''}</span><span class="stat-l">half-life of a shock, log(0.5) / log(φ)</span></div>
      <div class="stat"><span class="stat-v">±{band(12).toFixed(1)} → ±{Math.min(band(H), 999).toFixed(1)}</span><span class="stat-l">95% band half-width at 12 and 60 months</span></div>
      <div class="stat"><span class="stat-v">{Number.isFinite(longRun) ? '±' + longRun.toFixed(1) : 'none'}</span><span class="stat-l">long-run 95% range the band levels off at</span></div>
      <div class="stat"><span class="stat-v">{nearMean} of {N}</span><span class="stat-l">paths within 1 unit of the mean at month 60</span></div>
      <p class="note">
        {#if regime === 'stationary'}The band stops widening: however far ahead you look, the forecast is never worse than the long-run range.
        {:else if regime === 'unit'}The band grows like √h, without limit: it is twice as wide at 48 months as at 12. The best forecast is simply "where we are now".
        {:else}Each shock is amplified. Few economic series behave like this for long; it is the signature of a bubble.{/if}
      </p>
    </div>
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 300px; }
  .dial { display: grid; gap: .85rem; font-size: .84rem; }
  .regime { font-weight: 700; font-size: .92rem; padding: .45rem .65rem; border-radius: 8px; border: 1px solid var(--border); }
  .regime.stationary { color: var(--c-fitted); border-color: color-mix(in srgb, var(--c-fitted) 45%, transparent); }
  .regime.unit { color: var(--c-actual); border-color: color-mix(in srgb, var(--c-actual) 45%, transparent); }
  .regime.explosive { color: var(--danger); border-color: color-mix(in srgb, var(--danger) 45%, transparent); }
  .note { color: var(--text-2); margin: 0; line-height: 1.5; }
</style>
