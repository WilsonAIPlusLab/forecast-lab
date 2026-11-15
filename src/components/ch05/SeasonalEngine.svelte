<script lang="ts">
  // Signature explorable 3: the seasonal engine of Holt-Winters. Watch the 12 seasonal indices evolve,
  // additive ($ millions) vs multiplicative (% of level), on e-commerce sales whose seasonal swing grows with the business.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, ym, type Series } from '../../lib/ts';
  import { C, plotStyle, fmt, watchLayout } from '../../lib/viz/theme';
  import { hwFit } from './models';

  const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  let gamma = $state(0.2);
  let mult = $state(true);
  let year = $state(2025);
  let s = $state<Series | null>(null);
  let main: HTMLDivElement, side: HTMLDivElement;

  onMount(async () => { s = await loadSeries('MRTSSM4541USN', { start: '2000-01-01' }); });

  const years = $derived(s ? [s.data[12].date.getFullYear(), s.data[s.data.length - 1].date.getMonth() === 11 ? s.data[s.data.length - 1].date.getFullYear() : s.data[s.data.length - 1].date.getFullYear() - 1] : [2001, 2025]);

  const res = $derived.by(() => {
    if (!s) return null;
    const y = s.data.map((p) => p.value);
    const a = hwFit(y, 12, gamma, mult), other = hwFit(y, 12, gamma, !mult);
    return { a, other };
  });

  // indices applied in each calendar month of a given year
  function indices(yr: number) {
    if (!s || !res) return [];
    const out: { m: string; v: number }[] = [];
    s.data.forEach((p, t) => {
      if (p.date.getFullYear() === yr && res.a.applied[t] != null) out.push({ m: MON[p.date.getMonth()], v: mult ? (res.a.applied[t]! - 1) * 100 : res.a.applied[t]! });
    });
    return out;
  }

  function draw() {
    if (!main || !side || !s || !res) return;
    const W = main.clientWidth;
    const fitted = s.data.map((p, t) => ({ date: p.date, v: res.a.fitted[t] })).filter((r) => r.v != null);
    const y0 = new Date(year, 0, 1), y1 = new Date(year, 11, 31);
    main.replaceChildren(Plot.plot({
      width: W, height: Math.max(260, Math.min(360, W * 0.44)), marginLeft: 62, marginRight: 70, marginTop: 26,
      style: { ...plotStyle(), fontSize: '12px' }, x: { label: null }, y: { grid: true, nice: true, label: '$ millions (NSA)', tickFormat: fmt },
      ariaLabel: `E-commerce sales and one-step Holt-Winters ${mult ? 'multiplicative' : 'additive'} forecasts`,
      marks: [
        Plot.rectX([{ a: y0, b: y1 }], { x1: 'a', x2: 'b', fill: C.forecast, fillOpacity: 0.12 }),
        Plot.lineY(s.data, { x: 'date', y: 'value', stroke: C.history, strokeWidth: 1.25, strokeOpacity: 0.9 }),
        Plot.lineY(fitted, { x: 'date', y: 'v', stroke: C.fitted, strokeWidth: 2, strokeOpacity: 0.9 }),
        Plot.text([fitted[fitted.length - 1]], { x: 'date', y: 'v', text: () => 'One-step fit', dx: 6, textAnchor: 'start', fill: C.fitted, fontWeight: 650, fontSize: 12, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' } as any),
        Plot.tip(s.data.map((p, t) => ({ ...p, f: res.a.fitted[t] })).filter((r) => r.f != null), Plot.pointerX({ x: 'date', y: 'value', title: (r: any) => `${ym(r.date)}\nActual: ${fmt(r.value)} $ mn\nForecast a month earlier: ${fmt(r.f)} $ mn\nMiss: ${(100 * (r.value - r.f) / r.value).toFixed(1)}%` })),
      ],
    }));
    const now = indices(year), first = indices(years[0]);
    const both = [...first.map((r) => ({ ...r, k: String(years[0]) })), ...now.map((r) => ({ ...r, k: String(year) }))];
    const sw = side.clientWidth || 260;
    side.replaceChildren(Plot.plot({
      width: sw, height: 300, marginLeft: 34, marginRight: 8, marginTop: 10, marginBottom: 26,
      style: { ...plotStyle(), fontSize: '12px' },
      fx: { domain: MON, label: null, tickFormat: (d: string) => d[0], padding: 0.15 },
      x: { domain: [String(years[0]), String(year)], axis: null },
      y: { grid: true, label: null, tickFormat: (d: number) => (mult ? `${d > 0 ? '+' : ''}${d}%` : fmt(d)) },
      ariaLabel: `Seasonal indices by month in ${year} compared with ${years[0]}`,
      marks: [
        Plot.ruleY([0], { stroke: C.borderStrong }),
        Plot.barY(both, { fx: 'm', x: 'k', y: 'v', fill: (r: any) => (r.k === String(year) ? C.forecast : C.muted), fillOpacity: (r: any) => (r.k === String(year) ? 1 : 0.45) }),
        Plot.tip(both, Plot.pointer({ fx: 'm', x: 'k', y: 'v', title: (r: any) => `${r.m} ${r.k}\nSeasonal index: ${mult ? `${r.v > 0 ? '+' : ''}${r.v.toFixed(1)}% vs level` : `${r.v > 0 ? '+' : ''}${fmt(r.v)} $ mn vs level`}` })),
      ],
    }));
  }
  $effect(() => { res; year; draw(); });
  onMount(() => watchLayout(main, draw));
  const dec = $derived.by(() => { res; year; const a = indices(year).find((r) => r.m === 'Dec'), b = indices(years[0]).find((r) => r.m === 'Dec'); return { a: a?.v, b: b?.v }; });
</script>

<Explorable title="Inside the seasonal engine: dollars or percentages?" caption={`U.S. e-commerce sales, $ millions, <b>not seasonally adjusted</b> (MRTSSM4541USN, FRED), since 2000. Holt-Winters keeps 12 seasonal indices and nudges each one, by a share <b>γ</b> of the latest surprise, every time that month comes round. Set γ, switch between <b>additive</b> indices (dollars added to the level) and <b>multiplicative</b> ones (percent of the level), and drag the year to see the indices the model was using then (purple) against ${years[0]} (grey). α and β are re-estimated by a grid search; R's <code>hw()</code> estimates all three by maximum likelihood.`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Seasonality type">
      <button class:on={!mult} onclick={() => (mult = false)}>Additive ($)</button>
      <button class:on={mult} onclick={() => (mult = true)}>Multiplicative (%)</button>
    </div>
    <label class="sl">γ <input type="range" min="0" max="0.8" step="0.01" bind:value={gamma} aria-label="Seasonal smoothing gamma" aria-valuetext={`gamma ${gamma.toFixed(2)}`} /> <b>{gamma.toFixed(2)}</b></label>
    <label class="sl">Year <input type="range" min={years[0]} max={years[1]} step="1" bind:value={year} aria-label="Year whose seasonal indices are shown" /> <b>{year}</b></label>
  {/snippet}
  {#snippet aside()}
    <div class="se-head">Seasonal indices, {year} vs {years[0]}</div>
    <div bind:this={side} class="se-side"></div>
    {#if res}
      <div class="ro" aria-live="polite">
        <p>December: <b>{dec.a == null ? '—' : mult ? `${dec.a > 0 ? '+' : ''}${dec.a.toFixed(0)}%` : `+${fmt(dec.a)} $ mn`}</b> in {year}, vs {dec.b == null ? '—' : mult ? `${dec.b > 0 ? '+' : ''}${dec.b.toFixed(0)}%` : `+${fmt(dec.b)} $ mn`} in {years[0]}.</p>
        <p>One-step MAPE: <b class:good={res.a.mape < res.other.mape}>{res.a.mape.toFixed(2)}%</b> ({mult ? 'multiplicative' : 'additive'}) vs {res.other.mape.toFixed(2)}% ({mult ? 'additive' : 'multiplicative'}) at the same γ.</p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={main} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 260px; }
  .se-head { font-size: .8rem; font-weight: 650; color: var(--text-2); }
  .se-side { min-height: 300px; }
  .ro { font-size: .82rem; color: var(--text-2); }
  .ro p { margin: .3rem 0; }
  .good { color: var(--good); }
</style>
