<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, css, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { forecastSets, rocCurve, confusion, auc, pct } from './model';

  // Threshold → confusion matrix → point on the ROC curve; a cost ratio picks the cheapest threshold.
  type Key = 'insample' | 'oos';
  let key: Key = $state('insample');
  let th = $state(0.5);
  let k = $state(5);
  let elRoc: HTMLDivElement, elCost: HTMLDivElement;
  let sets = $state.raw<Record<Key, { label: string; p: number[]; y: number[] }> | null>(null);

  onMount(() => {
    let stops: (() => void)[] = [];
    forecastSets().then((f) => { sets = f.sets; stops = [watchLayout(elRoc, draw), watchLayout(elCost, draw)]; });
    return () => stops.forEach((s) => s());
  });

  const S = $derived(sets ? sets[key] : null);
  const roc = $derived(S ? rocCurve(S.p, S.y) : []);
  const A = $derived(S ? auc(S.p, S.y) : 0);
  const cm = $derived(S ? confusion(S.p, S.y, th) : null);
  const grid = Array.from({ length: 96 }, (_, i) => 0.01 + i * 0.01);
  const costs = $derived(S ? grid.map((t) => { const c = confusion(S.p, S.y, t); return { t, cost: (100 * (k * c.fn + c.fp)) / S.p.length }; }) : []);
  const best = $derived(costs.length ? costs.reduce((m, c) => (c.cost < m.cost ? c : m)) : { t: 0.5, cost: 0 });
  const myCost = $derived(cm && S ? (100 * (k * cm.fn + cm.fp)) / S.p.length : 0);

  function draw() {
    if (!elRoc || !S || !cm) return;
    const W1 = elRoc.clientWidth, H1 = Math.min(320, Math.max(240, W1));
    const r = Plot.plot({
      width: W1, height: H1, marginLeft: 44, marginBottom: 40, marginTop: 26, marginRight: 12, style: plotStyle(),
      x: { domain: [0, 1], label: 'False alarm rate →', labelAnchor: 'right', tickFormat: (v: number) => `${Math.round(v * 100)}%`, ticks: 5 },
      y: { domain: [0, 1], label: '↑ Hit rate', tickFormat: (v: number) => `${Math.round(v * 100)}%`, ticks: 5, grid: true },
      marks: [
        Plot.areaY(roc, { x: 'fpr', y: 'tpr', fill: C.forecast, fillOpacity: 0.1, }),
        Plot.line([[0, 0], [1, 1]], { stroke: C.muted, strokeDasharray: '4,4', strokeWidth: 1.25 }),
        Plot.text([[0.62, 0.55]], { text: () => 'Coin flip', fill: C.muted, fontSize: 12, rotate: W1 > 300 ? -38 : 0 }),
        Plot.line(roc, { x: 'fpr', y: 'tpr', stroke: C.forecast, strokeWidth: 2.5, }),
        Plot.text([[0.55, 0.12]], { text: () => `AUC = ${A.toFixed(3)}`, fill: C.text, fontSize: 13, fontWeight: 650, textAnchor: 'start' }),
        Plot.dot([[cm.fa, cm.hit]], { r: 7, fill: css('--warm'), stroke: C.surface, strokeWidth: 2 }),
        Plot.text([[cm.fa, cm.hit]], { text: () => `threshold ${pct(th)}`, dx: 10, dy: -10, textAnchor: 'start', fill: css('--warm'), fontSize: 12, fontWeight: 650, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
      ],
    });
    r.setAttribute('role', 'img'); r.setAttribute('aria-label', `ROC curve, area ${A.toFixed(3)}. At threshold ${pct(th)} the hit rate is ${pct(cm.hit)} and the false alarm rate ${pct(cm.fa)}.`);
    elRoc.replaceChildren(r);
    const W2 = elCost.clientWidth;
    const c = Plot.plot({
      width: W2, height: Math.min(320, Math.max(240, W1)), marginLeft: 44, marginBottom: 40, marginTop: 26, marginRight: 12, style: plotStyle(),
      x: { domain: [0, 1], label: 'Threshold →', labelAnchor: 'right', tickFormat: (v: number) => `${Math.round(v * 100)}%`, ticks: 5 },
      y: { label: '↑ Cost per 100 months', grid: true, zero: true },
      marks: [
        Plot.line(costs, { x: 't', y: 'cost', stroke: C.s[0], strokeWidth: 2.5 }),
        Plot.ruleX([best.t], { stroke: C.good, strokeDasharray: '4,4', strokeWidth: 2 }),
        Plot.text([best], { x: 't', y: 'cost', text: () => `Cheapest: ${pct(best.t)}`, dy: 16, dx: 6, textAnchor: 'start', fill: C.good, fontSize: 12, fontWeight: 650, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
        Plot.dot([{ t: th, cost: myCost }], { x: 't', y: 'cost', r: 7, fill: css('--warm'), stroke: C.surface, strokeWidth: 2 }),
      ],
    });
    c.setAttribute('role', 'img'); c.setAttribute('aria-label', `Expected cost by threshold when a missed recession costs ${k} times a false alarm. Cheapest threshold ${pct(best.t)}.`);
    elCost.replaceChildren(c);
  }
  $effect(() => { S; th; k; draw(); });
</script>

<Explorable title="The threshold game: trade missed recessions against false alarms" caption="A probability becomes a yes/no warning only when you pick a <b>threshold</b>. Slide it and watch the confusion matrix, the gold point on the ROC curve, and the cost. Then say how much worse a <b>missed recession</b> is than a <b>false alarm</b> (for a company: being caught with too much inventory and staff, versus cutting back for nothing). The green line marks the threshold with the lowest total cost. Switch to <b>out of sample</b> to see how the 1999 model fared on 2000–2025.">
  {#snippet controls()}
    <label class="sl">Threshold <input type="range" min="0.02" max="0.9" step="0.01" bind:value={th} aria-label="Warning threshold" aria-valuetext={`${pct(th)} probability`} /> <b>{pct(th)}</b></label>
    <label class="sl">Miss costs <input type="range" min="1" max="20" step="1" bind:value={k} aria-label="Cost of a missed recession relative to a false alarm" aria-valuetext={`${k} times a false alarm`} /> <b>{k}×</b> a false alarm</label>
    <div class="seg" role="group" aria-label="Sample">
      <button class:on={key === 'insample'} onclick={() => (key = 'insample')}>In sample, 1959–2025</button>
      <button class:on={key === 'oos'} onclick={() => (key = 'oos')}>Out of sample, 2000–2025</button>
    </div>
  {/snippet}
  {#snippet aside()}
    {#if cm}
      <div class="ms">
        <table class="cmx" aria-label="Confusion matrix">
          <thead><tr><th></th><th scope="col">Recession came</th><th scope="col">No recession</th></tr></thead>
          <tbody>
            <tr><th scope="row">Warned</th><td class="ok"><b>{cm.tp}</b><span>hits</span></td><td class="bad"><b>{cm.fp}</b><span>false alarms</span></td></tr>
            <tr><th scope="row">No warning</th><td class="bad"><b>{cm.fn}</b><span>misses</span></td><td class="ok"><b>{cm.tn}</b><span>quiet, correct</span></td></tr>
          </tbody>
        </table>
        <div class="rr"><span>Hit rate</span><b>{pct(cm.hit)}</b></div>
        <div class="rr"><span>False alarm rate</span><b>{pct(cm.fa)}</b></div>
        <div class="rr"><span>Your cost per 100 months</span><b>{myCost.toFixed(1)}</b></div>
        <div class="rr"><span>Cheapest threshold</span><b>{pct(best.t)} <button class="lnk" onclick={() => (th = best.t)}>use it</button></b></div>
        <p class="hint">Rule of thumb for well-calibrated probabilities: warn when p ≥ 1 ÷ (1 + {k}) = {pct(1 / (1 + k))}.</p>
      </div>
    {/if}
  {/snippet}
  <div class="two">
    <div bind:this={elRoc}></div>
    <div bind:this={elCost}></div>
  </div>
</Explorable>

<style>
  .two { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; min-height: 240px; }
  @media (max-width: 620px) { .two { grid-template-columns: 1fr; } }
  .ms { display: grid; gap: .45rem; font-size: .82rem; }
  .cmx { font-size: .76rem; margin: 0 0 .5rem; width: 100%; border-collapse: separate; border-spacing: 3px; }
  .cmx th { color: var(--muted); font-weight: 600; text-align: left; padding: .2rem; }
  .cmx td { padding: .4rem .45rem; border-radius: 6px; text-align: left; }
  .cmx td b { display: block; font-size: 1.05rem; font-variant-numeric: tabular-nums; color: var(--text); }
  .cmx td span { color: var(--muted); font-size: .76rem; }
  .cmx td.ok { background: color-mix(in srgb, var(--good) 12%, transparent); }
  .cmx td.bad { background: color-mix(in srgb, var(--danger) 12%, transparent); }
  .rr { display: flex; justify-content: space-between; gap: .5rem; color: var(--muted); }
  .rr b { color: var(--text); font-variant-numeric: tabular-nums; }
  .lnk { all: unset; cursor: pointer; color: var(--accent-text); font-size: .76rem; margin-left: .3rem; text-decoration: underline; }
  .lnk:focus-visible { outline: 2px solid var(--accent-2); }
  .hint { color: var(--muted); font-size: .76rem; margin: .3rem 0 0; }
</style>
