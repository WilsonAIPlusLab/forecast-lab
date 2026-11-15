<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { forecastSets, brier, pct } from './model';

  // Reliability diagram + Brier score: do "30%" forecasts come true about 30% of the time?
  type Key = 'insample' | 'oos';
  let key: Key = $state('insample');
  let mode: 'fixed' | 'quantile' = $state('fixed');
  let el: HTMLDivElement;
  let sets = $state.raw<Record<Key, { label: string; p: number[]; y: number[]; base: number }> | null>(null);

  onMount(() => {
    let stop = () => {};
    forecastSets().then((f) => { sets = f.sets; stop = watchLayout(el, draw); });
    return () => stop();
  });

  const S = $derived(sets ? sets[key] : null);
  const bins = $derived.by(() => {
    if (!S) return [];
    const idx = S.p.map((_, i) => i);
    let groups: number[][];
    if (mode === 'fixed') {
      const br = [0, 0.1, 0.2, 0.4, 0.6, 1];
      groups = br.slice(1).map((hi, j) => idx.filter((i) => (j === 0 ? S.p[i] >= 0 : S.p[i] > br[j]) && S.p[i] <= hi));
    } else {
      const s = idx.slice().sort((a, b) => S.p[a] - S.p[b]);
      groups = Array.from({ length: 10 }, (_, j) => s.slice(Math.round((j * s.length) / 10), Math.round(((j + 1) * s.length) / 10)));
    }
    return groups.filter((g) => g.length).map((g) => ({ n: g.length, f: g.reduce((a, i) => a + S.p[i], 0) / g.length, o: g.reduce((a, i) => a + S.y[i], 0) / g.length }));
  });
  const B = $derived(S ? brier(S.p, S.y) : 0);
  const Bc = $derived(S ? brier(S.p.map(() => S.base), S.y) : 0);
  const skill = $derived(Bc ? 1 - B / Bc : 0);

  function draw() {
    if (!el || !bins.length) return;
    const W = el.clientWidth, H = Math.min(360, Math.max(260, W * 0.62));
    const maxN = Math.max(...bins.map((b) => b.n));
    const chart = Plot.plot({
      width: W, height: H, marginLeft: 48, marginBottom: 42, marginTop: 26, marginRight: 16, style: plotStyle(),
      x: { domain: [0, 1], label: 'Forecast probability (bin average) →', labelAnchor: 'right', tickFormat: (v: number) => `${Math.round(v * 100)}%` },
      y: { domain: [0, 1], label: '↑ Share of months followed by recession', tickFormat: (v: number) => `${Math.round(v * 100)}%`, grid: true },
      r: { range: [3, 16], domain: [0, maxN] },
      marks: [
        Plot.line([[0, 0], [1, 1]], { stroke: C.muted, strokeDasharray: '4,4', strokeWidth: 1.25 }),
        Plot.text([[0.78, 0.86]], { text: () => 'Perfect calibration', fill: C.muted, fontSize: 12, textAnchor: 'end' }),
        Plot.text([[0.72, 0.2]], { text: () => 'Below the line: overconfident', fill: C.muted, fontSize: 12, textAnchor: 'middle' }),
        Plot.ruleX(bins, { x: 'f', y1: 'f', y2: 'o', stroke: C.danger, strokeOpacity: 0.6, strokeWidth: 2 }),
        Plot.line(bins, { x: 'f', y: 'o', stroke: C.forecast, strokeWidth: 2 }),
        Plot.dot(bins, { x: 'f', y: 'o', r: 'n', fill: C.forecast, fillOpacity: 0.85, stroke: C.surface, strokeWidth: 1.5 }),
        Plot.tip(bins, Plot.pointer({ x: 'f', y: 'o', title: (b: any) => `${b.n} months\nAverage forecast: ${pct(b.f, 1)}\nRecession followed: ${pct(b.o, 1)}` })),
      ],
    });
    chart.setAttribute('role', 'img');
    chart.setAttribute('aria-label', `Reliability diagram. Brier score ${B.toFixed(3)} against ${Bc.toFixed(3)} for always forecasting the base rate.`);
    el.replaceChildren(chart);
  }
  $effect(() => { bins; draw(); });
</script>

<Explorable title="Calibration: when the model says 40%, does a recession follow 40% of the time?" caption="Months are grouped by their forecast. Each dot compares the group's average forecast (left–right) with how often a recession really followed (up–down); bigger dots hold more months. On the dashed diagonal, the probabilities mean what they say. Red stalks show the gap. The <b>Brier score</b> on the right sums up accuracy and calibration in one number.">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Sample">
      <button class:on={key === 'insample'} onclick={() => (key = 'insample')}>In sample, 1959–2025</button>
      <button class:on={key === 'oos'} onclick={() => (key = 'oos')}>Out of sample, 2000–2025</button>
    </div>
    <div class="seg" role="group" aria-label="Grouping">
      <button class:on={mode === 'fixed'} onclick={() => (mode = 'fixed')}>5 ranges (as in the lab)</button>
      <button class:on={mode === 'quantile'} onclick={() => (mode = 'quantile')}>10 equal-size groups</button>
    </div>
  {/snippet}
  {#snippet aside()}
    {#if S}
      <div class="ms" aria-live="polite">
        <div class="stat"><span class="stat-v">{B.toFixed(3)}</span><span class="stat-l"><b>Brier score</b>: mean of (p − outcome)², lower is better</span></div>
        <div class="stat"><span class="stat-v">{Bc.toFixed(3)}</span><span class="stat-l"><b>Climatology</b>: always forecast the base rate, {pct(S.base, 1)}</span></div>
        <div class="stat"><span class="stat-v" class:neg={skill < 0}>{skill > 0 ? '+' : ''}{(100 * skill).toFixed(0)}%</span><span class="stat-l"><b>Brier skill score</b>: share of the benchmark's error removed</span></div>
        <p class="verdict">{skill > 0 ? 'The model beats a constant forecast.' : 'The model is worse than a constant forecast here. Its biggest errors: forecasts made in 2007–08, which missed the timing of the Great Recession, and in 2023–24, the long false alarm.'}</p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 260px; }
  .ms { display: grid; gap: .85rem; }
  .neg { color: var(--danger) !important; }
  .verdict { font-size: .8rem; color: var(--text-2); margin: 0; border-top: 1px dashed var(--border); padding-top: .6rem; }
</style>
