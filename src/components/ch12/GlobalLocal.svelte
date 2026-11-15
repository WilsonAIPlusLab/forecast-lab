<script lang="ts">
  // Signature explorable 4: one global model for 14 retail categories vs 14 local models, by length of history.
  // Data: precomputed natively in R by src/labs/ch12/make_data.R (same settings as Lab 13.4).
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import data from './global_local.json';

  type Run = { years: number; rows_per_series: number; category: string[]; local: number[]; global: number[] };
  const runs = data.runs as Run[];
  let ri = $state(1);
  let el: HTMLDivElement;
  const run = $derived(runs[ri]);
  const rows = $derived(run.category.map((c, i) => ({ c, local: run.local[i], global: run.global[i], gain: run.local[i] - run.global[i] })).sort((a, b) => b.gain - a.gain));
  const avgL = $derived(run.local.reduce((a, b) => a + b, 0) / run.local.length);
  const avgG = $derived(run.global.reduce((a, b) => a + b, 0) / run.global.length);
  const wins = $derived(rows.filter((r) => r.gain > 0).length);

  function draw() {
    if (!el) return;
    const W = el.clientWidth;
    const long = rows.flatMap((r) => [{ c: r.c, k: 'Local', v: r.local }, { c: r.c, k: 'Global', v: r.global }]);
    el.replaceChildren(Plot.plot({
      width: W, height: 40 + rows.length * 27, marginLeft: 170, marginRight: 20, marginBottom: 36,
      style: plotStyle(),
      ariaLabel: `Test MAPE by category, global versus local models, with ${run.years} years of training history. Global wins ${wins} of 14.`,
      x: { label: 'Test MAPE, % (lower is better)', grid: true, domain: [0, Math.max(8, ...rows.map((r) => Math.max(r.local, r.global))) * 1.05] },
      y: { domain: rows.map((r) => r.c), label: null, tickSize: 0 },
      marks: [
        Plot.ruleY(rows, { y: 'c', x1: 'local', x2: 'global', stroke: (r: any) => (r.gain > 0 ? C.s[0] : C.s[2]), strokeWidth: 3, strokeOpacity: 0.55 }),
        Plot.dot(long, { y: 'c', x: 'v', r: 5.5, fill: (d: any) => (d.k === 'Global' ? C.s[0] : 'none'), stroke: (d: any) => (d.k === 'Global' ? C.s[0] : C.s[2]), strokeWidth: 2.2, symbol: (d: any) => (d.k === 'Global' ? 'circle' : 'diamond') }),
        Plot.tip(long, Plot.pointer({ y: 'c', x: 'v', title: (d: any) => `${d.c}\n${d.k} model: ${d.v.toFixed(2)}% MAPE` })),
      ],
    }));
  }
  onMount(() => watchLayout(el, draw));
  $effect(() => { rows; draw(); });
</script>

<Explorable title="One model for 14 categories, or 14 models? It depends on how much history you have" caption={`Fourteen Census retail and food-service categories (NSA), one-month-ahead forecasts for ${data.test_from} to ${data.test_to}. <b>Global</b> (filled circle): one XGBoost model trained on all categories at once, with the category as a feature. <b>Local</b> (hollow diamond): a separate model per category. Same features and settings; early stopping on 2022 for every model. The line is colored by the winner. Data: FRED MRTSSM441USN to MRTSSM722USN.`}>
  {#snippet controls()}
    <label class="sl">History per category <input type="range" min="0" max={runs.length - 1} bind:value={ri} aria-label="Years of training history per category" aria-valuetext={`${run.years} years`} /> <b>{run.years} yrs</b></label>
  {/snippet}
  {#snippet aside()}
    <div class="side" aria-live="polite">
      <div class="eyebrow">Training on {2022 - run.years}–2022: {run.rows_per_series} months per category</div>
      <div class="cards">
        <div class="stat"><span class="stat-v loc">{avgL.toFixed(2)}%</span><span class="stat-l">average MAPE, 14 local models</span></div>
        <div class="stat"><span class="stat-v glo">{avgG.toFixed(2)}%</span><span class="stat-l">average MAPE, 1 global model</span></div>
        <div class="stat"><span class="stat-v">{wins} of 14</span><span class="stat-l">categories where global wins</span></div>
      </div>
      <p class="verdict">
        {#if avgG < avgL - 0.3}With only {run.years} years each, the shared model is clearly better: categories borrow December peaks and the 2020 shock from each other.
        {:else if avgG > avgL + 0.1}With {run.years} years each, local models have enough data of their own; sharing no longer helps on average.
        {:else}With {run.years} years each, it is roughly a tie on average (within 0.1 points).{/if}
      </p>
    </div>
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 420px; }
  .side { font-size: .84rem; color: var(--text-2); }
  .eyebrow { font-size: .8rem; font-weight: 650; color: var(--muted); margin-bottom: .6rem; }
  .cards { display: grid; gap: .7rem; margin-bottom: .8rem; }
  .loc { color: var(--c-s3) !important; }
  .glo { color: var(--c-s1) !important; }
  .verdict { margin: 0; line-height: 1.5; }
</style>
