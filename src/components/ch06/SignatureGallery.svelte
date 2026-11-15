<script lang="ts">
  // Signature explorable 3: ACF/PACF fingerprints of AR, MA and ARMA models (theory computed exactly in JS).
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { theoreticalAcf, pacfFromAcf, sampleAcf, simulateArma, arStationary } from './arma';

  const MODELS = {
    ar1: { label: 'AR(1)', p: 1, q: 0, a: { name: 'φ₁', min: -0.95, max: 0.95, v: 0.7 }, b: null },
    ar2: { label: 'AR(2)', p: 2, q: 0, a: { name: 'φ₁', min: -1.9, max: 1.9, v: 1.2 }, b: { name: 'φ₂', min: -0.95, max: 0.95, v: -0.5 } },
    ma1: { label: 'MA(1)', p: 0, q: 1, a: { name: 'θ₁', min: -0.95, max: 0.95, v: 0.7 }, b: null },
    ma2: { label: 'MA(2)', p: 0, q: 2, a: { name: 'θ₁', min: -0.95, max: 0.95, v: 0.6 }, b: { name: 'θ₂', min: -0.95, max: 0.95, v: 0.4 } },
    arma11: { label: 'ARMA(1,1)', p: 1, q: 1, a: { name: 'φ', min: -0.95, max: 0.95, v: 0.8 }, b: { name: 'θ', min: -0.95, max: 0.95, v: 0.5 } },
  } as const;
  type K = keyof typeof MODELS;
  const SIG: Record<K, { acf: string; pacf: string }> = {
    ar1: { acf: 'tails off geometrically (ρₖ = φᵏ)', pacf: 'cuts off after lag 1' },
    ar2: { acf: 'tails off, smoothly or in damped waves', pacf: 'cuts off after lag 2' },
    ma1: { acf: 'cuts off after lag 1', pacf: 'tails off' },
    ma2: { acf: 'cuts off after lag 2', pacf: 'tails off, often in waves' },
    arma11: { acf: 'tails off, starting after lag 1', pacf: 'tails off, starting after lag 1' },
  };

  let kind: K = $state('ar1');
  let a = $state(0.7);
  let b = $state(0);
  const N = 240, LAGS = 20;
  let pathEl: HTMLDivElement, acfEl: HTMLDivElement, pacfEl: HTMLDivElement;

  function pick(k: K) { kind = k; a = MODELS[k].a.v; b = MODELS[k].b?.v ?? 0; }

  const coefs = $derived.by(() => {
    const m = MODELS[kind];
    if (kind === 'ar1') return { phi: [a], theta: [] as number[] };
    if (kind === 'ar2') return { phi: [a, b], theta: [] as number[] };
    if (kind === 'ma1') return { phi: [] as number[], theta: [a] };
    if (kind === 'ma2') return { phi: [] as number[], theta: [a, b] };
    return { phi: [a], theta: [b] };
  });
  const ok = $derived(arStationary(coefs.phi));
  const model = $derived.by(() => {
    if (!ok) return null;
    const rho = theoreticalAcf(coefs.phi, coefs.theta, LAGS);
    const path = simulateArma(coefs.phi, coefs.theta, N, 2026);
    return { rho, pacf: pacfFromAcf(rho), path, srho: sampleAcf(path, LAGS), spacf: pacfFromAcf(sampleAcf(path, LAGS)) };
  });

  function lolli(el: HTMLDivElement, theo: number[], samp: number[], label: string, color: string) {
    const ci = 1.96 / Math.sqrt(N);
    const d = theo.map((v, i) => ({ lag: i + 1, v, s: samp[i] }));
    const chart = Plot.plot({
      width: el.clientWidth, height: 220, marginLeft: 40, marginTop: 10, marginBottom: 32,
      style: plotStyle(), x: { label: 'lag', domain: [0.5, LAGS + 0.5], ticks: 10 }, y: { label, domain: [-1, 1], grid: true, ticks: 5 },
      marks: [
        Plot.areaY([{ l: 0.5 }, { l: LAGS + 0.5 }], { x: 'l', y1: -ci, y2: ci, fill: C.muted, fillOpacity: 0.12 }),
        Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
        Plot.ruleX(d, { x: 'lag', y1: 0, y2: 'v', stroke: color, strokeWidth: 2.5 }),
        Plot.dot(d, { x: 'lag', y: 'v', fill: color, r: 4 }),
        Plot.dot(d, { x: 'lag', y: 's', stroke: C.text2, r: 3.2, strokeWidth: 1.3 }),
        Plot.tip(d, Plot.pointerX({ x: 'lag', y: 'v', title: (r: any) => `Lag ${r.lag}\nTheoretical: ${r.v.toFixed(3)}\nFrom the simulated path: ${r.s.toFixed(3)}` })),
      ],
    });
    chart.setAttribute('aria-label', `${label} of ${MODELS[kind].label}: theoretical values as lollipops and sample values as open circles`);
    el.replaceChildren(chart);
  }

  function draw() {
    if (!pathEl || !acfEl || !pacfEl) return;
    if (!model) { [pathEl, acfEl, pacfEl].forEach((e) => e.replaceChildren()); return; }
    const d = model.path.map((v, t) => ({ t: t + 1, v }));
    const chart = Plot.plot({
      width: pathEl.clientWidth, height: 150, marginLeft: 40, marginTop: 8, marginBottom: 26,
      style: plotStyle(), x: { label: 'month', ticks: 8 }, y: { label: null, grid: true, ticks: 4 },
      marks: [Plot.ruleY([0], { stroke: C.borderStrong, strokeDasharray: '4 4' }), Plot.lineY(d, { x: 't', y: 'v', stroke: C.history, strokeWidth: 1.4 })],
    });
    chart.setAttribute('aria-label', `A simulated path of ${N} months from the ${MODELS[kind].label} model`);
    pathEl.replaceChildren(chart);
    lolli(acfEl, model.rho, model.srho, 'ACF', C.s[0]);
    lolli(pacfEl, model.pacf, model.spacf, 'PACF', C.s[2]);
  }

  $effect(() => { model; draw(); });
  onMount(() => {
    const offs = [pathEl, acfEl, pacfEl].map((e) => watchLayout(e, draw));
    return () => offs.forEach((f) => f());
  });
  const m = $derived(MODELS[kind]);
</script>

<Explorable title="Every model leaves a fingerprint in the ACF and PACF" caption="Pick a model and move its coefficients. Solid lollipops are the exact theoretical autocorrelations (computed from the model's equations); open circles are what you would actually measure from the 240-month simulated path above them. The grey band is ±1.96/√n: sample bars inside it are indistinguishable from zero. Notice how noisy real fingerprints are compared with the theory.">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Model">
      {#each Object.entries(MODELS) as [k, v]}<button class:on={kind === k} onclick={() => pick(k as K)}>{v.label}</button>{/each}
    </div>
    <label class="sl">{m.a.name}
      <input type="range" min={m.a.min} max={m.a.max} step="0.05" bind:value={a} aria-label={`Coefficient ${m.a.name}`} aria-valuetext={`${m.a.name} equals ${a.toFixed(2)}`} />
      <b>{a.toFixed(2)}</b>
    </label>
    {#if m.b}
      <label class="sl">{m.b.name}
        <input type="range" min={m.b.min} max={m.b.max} step="0.05" bind:value={b} aria-label={`Coefficient ${m.b.name}`} aria-valuetext={`${m.b.name} equals ${b.toFixed(2)}`} />
        <b>{b.toFixed(2)}</b>
      </label>
    {/if}
  {/snippet}
  <div class="path" bind:this={pathEl}></div>
  {#if !ok}
    <p class="warn" role="status">These AR coefficients make the process nonstationary (a root on or inside the unit circle), so it has no fixed ACF. For an AR(2), stationarity needs φ₁ + φ₂ &lt; 1, φ₂ − φ₁ &lt; 1 and |φ₂| &lt; 1. Pull φ₁ or φ₂ back toward zero.</p>
  {/if}
  <div class="pair">
    <div><div class="lab">ACF {#if ok}<span>{SIG[kind].acf}</span>{/if}</div><div bind:this={acfEl}></div></div>
    <div><div class="lab">PACF {#if ok}<span>{SIG[kind].pacf}</span>{/if}</div><div bind:this={pacfEl}></div></div>
  </div>
</Explorable>

<style>
  .path { min-height: 150px; margin-bottom: .6rem; }
  .pair { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1.2rem; }
  @media (max-width: 760px) { .pair { grid-template-columns: 1fr; } }
  .pair > div > div:last-child { min-height: 220px; }
  .lab { font-weight: 700; color: var(--text); font-size: .9rem; display: flex; gap: .6rem; align-items: baseline; flex-wrap: wrap; }
  .lab span { font-weight: 500; color: var(--accent-text); font-size: .84rem; }
  .warn { color: var(--danger); font-size: .86rem; border: 1px solid color-mix(in srgb, var(--danger) 40%, transparent); border-radius: 8px; padding: .6rem .8rem; }
</style>
