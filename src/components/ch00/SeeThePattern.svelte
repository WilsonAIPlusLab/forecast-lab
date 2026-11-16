<script lang="ts">
  // Plot before you model: the same retail sales drawn three ways, so trend and seasonality jump out.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { history, bnShort, monthName } from './data';
  import { BASE } from '../../lib/runtime/status';

  type View = 'time' | 'years' | 'yoy';
  const VIEWS: { k: View; label: string }[] = [
    { k: 'time', label: 'Over time' },
    { k: 'years', label: 'Year by year' },
    { k: 'yoy', label: 'Change vs a year ago' },
  ];
  const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const rows = history.map((p) => ({ ...p, y: p.date.getFullYear(), m: p.date.getMonth() }));
  const firstY = rows[0].y, lastY = rows[rows.length - 1].y;
  // year-over-year % change: this month vs the same month 12 months earlier
  const yoy = rows.slice(12).map((p, i) => ({ ...p, g: 100 * (p.value / rows[i].value - 1) }));

  let view = $state<View>('time');
  let year = $state(2025);
  let el: HTMLDivElement;

  const yr = $derived(rows.filter((p) => p.y === year));
  const full = $derived(yr.length === 12);
  const avg = $derived(yr.reduce((a, p) => a + p.value, 0) / yr.length);
  const dec = $derived(yr.find((p) => p.m === 11));
  const nov = $derived(yr.find((p) => p.m === 10));
  const avg2012 = rows.filter((p) => p.y === firstY).reduce((a, p) => a + p.value, 0) / 12;
  const yy = $derived(yoy.filter((p) => p.y === year));
  const yyAvg = $derived(yy.length ? yy.reduce((a, p) => a + p.g, 0) / yy.length : NaN);
  const yyMin = $derived(yy.length ? yy.reduce((a, p) => (p.g < a.g ? p : a)) : null);
  const yyMax = $derived(yy.length ? yy.reduce((a, p) => (p.g > a.g ? p : a)) : null);
  const minYear = $derived(view === 'yoy' ? firstY + 1 : firstY);

  $effect(() => { if (year < minYear) year = minYear; });

  const sg = (g: number) => `${g >= 0 ? '+' : '−'}${Math.abs(g).toFixed(1)}%`;   // signed percent, e.g. +5.2%
  const lbl = (extra = {}) => ({ fontSize: 12, fontWeight: 650, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke', ...extra });

  function draw() {
    if (!el) return;
    const W = el.clientWidth, narrow = W < 560;
    const Ht = Math.max(290, Math.min(400, W * 0.48));
    let marks: any[] = [];
    let opts: any = {};
    if (view === 'time') {
      const decs = rows.filter((p) => p.m === 11);
      const apr20 = rows.find((p) => p.y === 2020 && p.m === 3)!;
      marks = [
        Plot.lineY(rows, { x: 'date', y: 'value', stroke: C.history, strokeWidth: 1.6 }),
        Plot.lineY(yr, { x: 'date', y: 'value', stroke: C.forecast, strokeWidth: 3 }),
        Plot.dot(decs, { x: 'date', y: 'value', r: 3.2, fill: C.actual, stroke: C.surface, strokeWidth: 1 }),
        Plot.text([decs[decs.length - 1]], { x: 'date', y: 'value', text: () => 'Each gold dot = December', textAnchor: 'end', dx: -8, dy: -4, fill: C.text2, ...lbl() }),
        Plot.text([apr20], { x: 'date', y: 'value', text: () => 'Apr 2020: COVID shutdowns', textAnchor: 'start', dx: 8, dy: 12, fill: C.danger, ...lbl() }),
        Plot.tip(rows, Plot.pointerX({ x: 'date', y: 'value', title: (r: any) => `${monthName(r.date, false)}\n${bnShort(r.value)} (≈ $${(r.value / 1000).toFixed(1)} billion)` })),
      ];
      opts = { x: { label: null, ticks: narrow ? 5 : 8 }, y: { grid: true, label: '$ billions per month', labelAnchor: 'top', tickFormat: (v: number) => `${Math.round(v / 1000)}` } };
    } else if (view === 'years') {
      const others = rows.filter((p) => p.y !== year);
      const ends = [firstY, year].filter((v, i, a) => a.indexOf(v) === i).map((y) => rows.filter((p) => p.y === y).at(-1)!);
      marks = [
        Plot.lineY(others, { x: 'm', y: 'value', z: 'y', stroke: C.history, strokeWidth: 1.25, strokeOpacity: 0.4 }),
        Plot.lineY(yr, { x: 'm', y: 'value', stroke: C.forecast, strokeWidth: 3 }),
        Plot.dot(yr, { x: 'm', y: 'value', r: 3, fill: C.forecast }),
        Plot.text(ends, { x: 'm', y: 'value', text: (p: any) => String(p.y), textAnchor: 'start', dx: 7, fill: (p: any) => (p.y === year ? C.forecast : C.text2), ...lbl() }),
        Plot.tip(rows, Plot.pointer({ x: 'm', y: 'value', title: (r: any) => `${MON[r.m]} ${r.y}\n${bnShort(r.value)}` })),
      ];
      opts = { x: { label: null, domain: [0, 11.6], ticks: narrow ? [0, 2, 4, 6, 8, 11] : [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], tickFormat: (m: number) => MON[m] ?? '' }, y: { grid: true, label: '$ billions per month', labelAnchor: 'top', tickFormat: (v: number) => `${Math.round(v / 1000)}` } };
    } else {
      const lo = yoy.reduce((a, p) => (p.g < a.g ? p : a)), hi = yoy.reduce((a, p) => (p.g > a.g ? p : a));
      marks = [
        Plot.ruleY([0], { stroke: C.borderStrong }),
        Plot.lineY(yoy, { x: 'date', y: 'g', stroke: C.history, strokeWidth: 1.6 }),
        Plot.lineY(yy, { x: 'date', y: 'g', stroke: C.forecast, strokeWidth: 3 }),
        Plot.dot([lo, hi], { x: 'date', y: 'g', r: 4, fill: C.danger }),
        Plot.text([lo], { x: 'date', y: 'g', text: (p: any) => `${MON[p.m]} ${p.y}: ${p.g.toFixed(0)}%`, textAnchor: 'start', dx: 8, fill: C.danger, ...lbl() }),
        Plot.text([hi], { x: 'date', y: 'g', text: (p: any) => `${MON[p.m]} ${p.y}: +${p.g.toFixed(0)}%`, textAnchor: 'start', dx: 8, fill: C.danger, ...lbl() }),
        Plot.tip(yoy, Plot.pointerX({ x: 'date', y: 'g', title: (r: any) => `${monthName(r.date, false)}\n${r.g >= 0 ? '+' : ''}${r.g.toFixed(1)}% vs ${MON[r.m]} ${r.y - 1}` })),
      ];
      opts = { x: { label: null, ticks: narrow ? 5 : 8 }, y: { grid: true, label: '% change vs same month a year earlier', labelAnchor: 'top', tickFormat: (v: number) => `${v > 0 ? '+' : ''}${v}%` } };
    }
    const chart = Plot.plot({ width: W, height: Ht, marginLeft: 52, marginRight: view === 'years' ? 44 : 16, marginTop: 22, style: plotStyle(), ...opts, marks });
    el.replaceChildren(chart);
  }

  $effect(() => { view; year; draw(); });
  onMount(() => watchLayout(el, draw));

  const ariaText = $derived(view === 'time'
    ? 'Line chart of monthly U.S. retail sales since 2012: a rising trend, a peak every December, and a sharp drop in April 2020.'
    : view === 'years'
      ? `Each year's retail sales drawn from January to December on the same axis, with ${year} highlighted. Every year rises toward a December peak, and later years sit higher.`
      : `Year-over-year percent change in retail sales since ${firstY + 1}, with ${year} highlighted. The seasonal pattern disappears; the 2020 crash and 2021 rebound stand out.`);
</script>

<Explorable title="Plot before you model: one series, three honest pictures" caption="U.S. retail sales (RSXFSN), $ millions per month shown as $ billions, not seasonally adjusted, January 2012 onward. Switch the view, then slide the year to highlight one year in every view. Hover for exact values.">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="View">
      {#each VIEWS as v}<button class:on={view === v.k} aria-pressed={view === v.k} onclick={() => (view = v.k)}>{v.label}</button>{/each}
    </div>
    <label class="sl">Highlight <input type="range" min={minYear} max={lastY} step="1" bind:value={year} aria-label="Year to highlight" /> <b>{year}</b></label>
  {/snippet}
  {#snippet aside()}
    <div class="sp" aria-live="polite">
      {#if view === 'time'}
        <div class="eyebrow">What to see</div>
        <p><b>Trend:</b> the whole line drifts up. In {year}, sales averaged <b>{bnShort(avg)}</b> a month{year !== firstY ? `, ${((avg / avg2012 - 1) * 100).toFixed(0)}% more than in ${firstY}` : ''}{full ? '' : ' (part year)'}.</p>
        <p><b>Seasonality:</b> the same zigzag every year, topped by a December peak (gold dots).</p>
        <p><b>Surprises:</b> April 2020 broke the pattern. A model fitted through it should not treat it as normal.</p>
      {:else if view === 'years'}
        <div class="eyebrow">What to see</div>
        <p><b>Seasonality</b> is the <i>shape</i>: every line climbs to December, then the next year starts low in January and February.</p>
        {#if dec && nov}<p>In {year}, December was <b>{((dec.value / nov.value - 1) * 100).toFixed(1)}%</b> above November and <b>{((dec.value / avg - 1) * 100).toFixed(0)}%</b> above the year's average month.</p>{:else}<p>{year} is not complete yet: no December data.</p>{/if}
        <p><b>Trend</b> is the <i>stacking</i>: later years sit higher.</p>
      {:else}
        <div class="eyebrow">What to see</div>
        <p>Comparing each month with the <b>same month a year earlier</b> cancels the seasonal zigzag. What is left is growth.</p>
        {#if yyMin && yyMax}<p>In {year}, growth vs a year earlier averaged <b>{yyAvg >= 0 ? '+' : ''}{yyAvg.toFixed(1)}%</b> (from {sg(yyMin.g)} in {MON[yyMin.m]} to {sg(yyMax.g)} in {MON[yyMax.m]}).</p>{/if}
        <p>These are dollar figures, so part of the growth is higher prices (<a href={`${BASE}chapters/time-series-data/#real-vs-nominal-more-stuff-or-higher-prices`}>Chapter 1</a>).</p>
      {/if}
    </div>
  {/snippet}
  <div bind:this={el} class="chart" role="img" aria-label={ariaText}></div>
</Explorable>

<style>
  .chart { min-height: 290px; }
  .sp { font-size: .86rem; color: var(--text-2); display: grid; gap: .55rem; }
  .sp p { margin: 0; line-height: 1.5; }
</style>
