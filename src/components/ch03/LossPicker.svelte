<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, fcNaive, fcSNaive, fcDrift, mean } from '../../lib/ts';
  import { C, plotStyle, fmt, watchLayout } from '../../lib/viz/theme';

  // The business loss decides the winner. Retail sales (RSXFSN), trained through Dec 2022, tested from Jan 2023
  // (the same split as the scorecard lab). Cost per month = r × (under-forecast) + 1 × (over-forecast), in $ millions.
  // With r = 1 the cost is exactly the MAE. A "buffer" shades seasonal naive up by b%.
  let r = $state(1);                          // cost of $1M under-forecast relative to $1M over-forecast
  let b = $state(0);                          // safety buffer on seasonal naive, %
  let act: number[] = $state([]);
  let F: Record<string, number[]> = $state({});
  let el: HTMLDivElement, el2: HTMLDivElement;

  onMount(async () => {
    const s = await loadSeries('RSXFSN', { start: '2010-01-01' });
    const k = s.data.findIndex((p) => p.date.getFullYear() === 2023 && p.date.getMonth() === 0);
    const y = s.data.slice(0, k).map((p) => p.value);
    act = s.data.slice(k).map((p) => p.value);
    const h = act.length;
    F = { 'Seasonal naive': fcSNaive(y, h, 12), Naive: fcNaive(y, h), Drift: fcDrift(y, h) };
  });

  const cost = (fc: number[], ratio: number) => mean(act.map((a, i) => { const e = a - fc[i]; return e > 0 ? ratio * e : -e; }));
  const shade = (fc: number[], pct: number) => fc.map((v) => v * (1 + pct / 100));

  const bars = $derived.by(() => {
    if (!act.length) return [];
    const out = Object.entries(F).map(([name, fc]) => ({ name, cost: cost(fc, r), under: mean(act.map((a, i) => (a > fc[i] ? 1 : 0))) }));
    if (b > 0) out.push({ name: `Seasonal naive + ${b}%`, cost: cost(shade(F['Seasonal naive'], b), r), under: mean(act.map((a, i) => (a > F['Seasonal naive'][i] * (1 + b / 100) ? 1 : 0))) });
    const lo = Math.min(...out.map((d) => d.cost));
    return out.map((d) => ({ ...d, best: d.cost === lo }));
  });
  // Cost of seasonal naive + buffer, for buffers 0..10% in steps of 0.5
  const curve = $derived.by(() => (act.length ? Array.from({ length: 21 }, (_, i) => ({ b: i / 2, cost: cost(shade(F['Seasonal naive'], i / 2), r) })) : []));
  const bestB = $derived(curve.length ? curve.reduce((p, q) => (q.cost < p.cost ? q : p)) : null);
  const winner = $derived(bars.find((d) => d.best)?.name ?? '');

  function draw() {
    if (!el || !bars.length) return;
    const W = el.clientWidth;
    if (W < 200) return;                      // not laid out yet: watchLayout redraws once it has a width
    el.replaceChildren(Plot.plot({
      width: W, height: 56 + 38 * bars.length, marginLeft: Math.min(170, W * 0.36), marginRight: Math.min(70, W * 0.18), marginTop: 6, marginBottom: 42,
      style: plotStyle(), x: { grid: true, nice: true, tickFormat: fmt, label: 'Average business cost per month (cost units) →', labelAnchor: 'center', labelOffset: 36, ticks: W < 500 ? 3 : 6 },
      y: { label: null, domain: bars.map((d) => d.name), tickSize: 0 },
      ariaLabel: `Average monthly business cost of each retail forecast when an under-forecast costs ${r} times an over-forecast. Lowest: ${winner}.`,
      marks: [
        Plot.barX(bars, { y: 'name', x: 'cost', fill: (d: any) => (d.best ? C.good : C.s[0]), fillOpacity: (d: any) => (d.best ? 0.9 : 0.55) }),
        Plot.text(bars.filter((d) => !d.best), { y: 'name', x: 'cost', text: (d: any) => fmt(d.cost), textAnchor: 'start', dx: 5, fill: C.text, fontSize: 12 }),
        Plot.text(bars.filter((d) => d.best), { y: 'name', x: 'cost', text: (d: any) => fmt(d.cost) + '  ← lowest', textAnchor: 'start', dx: 5, fill: C.text, fontSize: 12, fontWeight: 700 }),
        Plot.tip(bars, Plot.pointerY({ y: 'name', x: 'cost', title: (d: any) => `${d.name}\nAverage cost: ${fmt(d.cost)} units a month\nToo low in ${Math.round(100 * d.under)}% of test months` })),
      ],
    }));
    if (!el2 || !curve.length) return;
    el2.replaceChildren(Plot.plot({
      width: el2.clientWidth, height: 200, marginLeft: 60, marginRight: 16, marginTop: 26, marginBottom: 42,
      style: plotStyle(), x: { label: 'Buffer added to seasonal naive (%) →', labelAnchor: 'center', labelOffset: 36, ticks: 6 }, y: { grid: true, nice: true, tickFormat: fmt, label: '↑ cost' },
      ariaLabel: `Cost of seasonal naive plus a buffer, for buffers from 0 to 10 percent, when an under-forecast costs ${r} times an over-forecast. Cheapest buffer: ${bestB?.b}%.`,
      marks: [
        Plot.lineY(curve, { x: 'b', y: 'cost', stroke: C.s[0], strokeWidth: 2.2 }),
        Plot.dot([bestB], { x: 'b', y: 'cost', r: 5, fill: C.good }),
        Plot.text([bestB], { x: 'b', y: 'cost', text: (d: any) => `cheapest: +${d.b}%`, dy: -12, fill: C.good, fontSize: 12, fontWeight: 700, stroke: 'var(--surface)', strokeWidth: 3, paintOrder: 'stroke' }),
        Plot.ruleX([b], { stroke: C.forecast, strokeDasharray: '4,3', strokeWidth: 1.5 }),
      ],
    }));
  }

  $effect(() => { bars; curve; draw(); });
  onMount(() => { const off1 = watchLayout(el, draw); return off1; });
</script>

<Explorable title="The cost of a mistake decides which forecast wins" caption={`Retail sales forecasts for January 2023 onward (same split as the scorecard lab). One cost unit = the cost of \$1 million of leftover stock; an under-forecast (empty shelves, lost sales) costs <b>r</b> units per \$1 million. At r = 1 the cost <i>is</i> the MAE, and seasonal naive wins. Raise r: around r = 2, naive takes over, only because it repeats December's peak all year and so is almost always too high. The lower chart shows the better answer: keep the good forecast and add a buffer. Caution: here the buffer is tuned on the test period itself, which is peeking. In practice you would choose it on earlier data. Data: FRED RSXFSN, $ millions, not seasonally adjusted.`}>
  {#snippet controls()}
    <label class="sl">Cost of under- vs over-forecast <input type="range" min="1" max="10" step="0.5" bind:value={r} aria-label="Cost of under-forecasting relative to over-forecasting" /> <b>{r}×</b></label>
    <label class="sl">Buffer on seasonal naive <input type="range" min="0" max="10" step="0.5" bind:value={b} aria-label="Percent added to the seasonal naive forecast" /> <b>+{b}%</b></label>
  {/snippet}
  {#snippet aside()}
    {#if bars.length}
      <div class="ms" aria-live="polite">
        <div class="stat"><span class="stat-v small">{winner}</span><span class="stat-l"><b>Cheapest forecast</b> when a lost sale costs {r}× leftover stock</span></div>
        {#if bestB}<div class="stat"><span class="stat-v">+{bestB.b}%</span><span class="stat-l"><b>Cheapest buffer</b> for seasonal naive at this cost ratio</span></div>{/if}
        <p class="note">{r === 1 ? 'At 1× the cost is the MAE: every $1 million of miss counts the same, whichever way it goes. Even so, a small buffer helps, because seasonal naive is biased low: it ignores growth.' : `At ${r}× an under-forecast hurts ${r} times as much, so forecasts that err on the high side win, and the cheapest buffer grows.`}</p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart"></div>
  <div bind:this={el2} class="chart2"></div>
</Explorable>

<style>
  .chart { min-height: 150px; }
  .chart2 { min-height: 200px; margin-top: .6rem; }
  .ms { display: grid; gap: .8rem; font-size: .82rem; }
  .stat-v.small { font-size: 1.15rem; }
  .note { margin: 0; color: var(--text-2); line-height: 1.45; }
</style>
