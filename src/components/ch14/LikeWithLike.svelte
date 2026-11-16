<script lang="ts">
  // "Same forecast, two headlines": a forecast for a not-seasonally-adjusted series compared with the latest month
  // (mostly measures the calendar) versus the same month a year earlier (like with like). Slide the horizon.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, futureDates } from '../../lib/ts';
  import { C, css, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { fitForecast } from './engine';
  import { seriesById, fmtShort, monYr, monthYear } from './series';

  const IDS = ['RSXFSN', 'TOTALNSA', 'HOUSTNSA', 'PAYEMS'];
  let sid = $state('RSXFSN');
  let h = $state(3);
  let d: { date: Date; value: number }[] = $state([]);
  let el: HTMLDivElement;
  const meta = $derived(seriesById(sid));

  let seq = 0;
  $effect(() => {
    const id = sid, my = ++seq;
    loadSeries(id, { start: '2010-01-01' }).then((s) => { if (my === seq) d = s.data.map((p) => ({ date: p.date, value: p.value / seriesById(id).div })); });
  });

  // Holt-Winters multiplicative, fitted once on all the data (the Studio's best method for retail sales).
  const fc = $derived.by(() => {
    if (!d.length) return null;
    const y = d.map((p) => p.value), T = y.length;
    const f = fitForecast('hwm', y, 12, 12).fc;
    const dates = futureDates(d[T - 1].date, 12, 12);
    return { rows: dates.map((date, i) => ({ date, value: f[i] })), last: d[T - 1], hist: d.slice(T - 24) };
  });
  const cur = $derived.by(() => {
    if (!fc) return null;
    const target = fc.rows[h - 1];
    const ly = d[d.length - 1 - 12 + h];           // same calendar month, one year before the target
    const vsLatest = (target.value / fc.last.value - 1) * 100;
    const vsLY = (target.value / ly.value - 1) * 100;
    // range of the "vs latest" headline across all 12 horizons, to show how much the calendar moves it
    const all = fc.rows.map((r) => (r.value / fc.last.value - 1) * 100);
    const allLY = fc.rows.map((r, i) => (r.value / d[d.length - 12 + i].value - 1) * 100);
    return { target, ly, vsLatest, vsLY, lo: Math.min(...all), hi: Math.max(...all), loLY: Math.min(...allLY), hiLY: Math.max(...allLY) };
  });
  const sg = (v: number) => `${v < 0 ? '−' : '+'}${Math.abs(v).toFixed(1)}%`;

  function draw() {
    if (!fc || !cur || !el) return;
    const W = el.clientWidth;
    if (W < 200) return; // not laid out yet (or mid-resize): skip, watchLayout redraws
    const pts = [
      { date: fc.last.date, value: fc.last.value, lab: 'Latest', col: C.history },
      { date: cur.ly.date, value: cur.ly.value, lab: 'Same month, a year earlier', col: C.actual },
      { date: cur.target.date, value: cur.target.value, lab: 'Forecast', col: css('--accent-text') },
    ];
    const p = Plot.plot({
      width: W, height: 260, marginLeft: 56, marginRight: 16, marginTop: 24, style: plotStyle(),
      x: { label: null }, y: { grid: true, label: `↑ ${meta.unitAxis}`, tickFormat: (v: number) => fmtShort(meta, v) },
      marks: [
        Plot.lineY(fc.hist, { x: 'date', y: 'value', stroke: C.history, strokeWidth: 2 }),
        Plot.lineY([fc.last, ...fc.rows], { x: 'date', y: 'value', stroke: C.forecast, strokeWidth: 2, strokeDasharray: '5,3' }),
        Plot.link([0], { x1: () => cur.ly.date, y1: () => cur.ly.value, x2: () => cur.target.date, y2: () => cur.target.value, stroke: C.actual, strokeWidth: 1.5, strokeDasharray: '2,3' }),
        Plot.link([0], { x1: () => fc.last.date, y1: () => fc.last.value, x2: () => cur.target.date, y2: () => cur.target.value, stroke: C.muted, strokeWidth: 1.25, strokeOpacity: 0.6 }),
        Plot.dot(pts, { x: 'date', y: 'value', r: 6, fill: 'col', stroke: C.surface, strokeWidth: 2, symbol: (_: any, i: number) => ['circle', 'square', 'diamond'][i] }),
        Plot.text(pts, { x: 'date', y: 'value', text: (q: any) => (q.lab === 'Same month, a year earlier' ? monYr(q.date) : q.lab), dy: -13, fill: 'col',
          fontWeight: 700, fontSize: 12, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
        Plot.tip(pts,Plot.pointer({ x: 'date', y: 'value', title: (q: any) => `${q.lab}: ${monYr(q.date)}\n${fmtShort(meta, q.value)} ${meta.unitAxis}` })),
      ],
    });
    p.setAttribute('role', 'img');
    p.setAttribute('aria-label', `${meta.label}: last 24 months and a 12-month forecast. The forecast for ${monthYear(cur.target.date)} is ${fmtShort(meta, cur.target.value)}, ${sg(cur.vsLatest)} on the latest month and ${sg(cur.vsLY)} on the same month a year earlier.`);
    el.replaceChildren(p);
  }
  $effect(() => { cur; draw(); });
  onMount(() => watchLayout(el, draw));
</script>

<Explorable title="Same forecast, two headlines: compare like with like" caption="The violet dashed line is a Holt-Winters multiplicative forecast fitted on all the data. Slide the horizon to pick a target month. The grey line joins it to the <b>latest month</b>; the gold dotted line joins it to the <b>same month a year earlier</b>. For a series that is <b>not seasonally adjusted</b>, the first comparison mostly measures the calendar (December versus September), so its sign and size jump around as you slide. The second compares like with like. For a seasonally adjusted series such as payroll jobs, the two headlines tell a similar story.">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Series">
      {#each IDS as id}<button class:on={sid === id} aria-pressed={sid === id} onclick={() => (sid = id)}>{seriesById(id).label} ({seriesById(id).adj})</button>{/each}
    </div>
    <label class="sl">Months ahead <input type="range" min="1" max="12" step="1" bind:value={h} aria-label="Forecast horizon in months" aria-valuetext={cur ? `${h} months ahead, ${monthYear(cur.target.date)}` : `${h} months ahead`} /> <b>{h}</b></label>
  {/snippet}
  {#snippet aside()}
    {#if cur}
      <div class="rd">
        <div class="stat"><span class="stat-v">{fmtShort(meta, cur.target.value)}</span><span class="stat-l">forecast for {monthYear(cur.target.date)}, {meta.unitAxis}</span></div>
        <div class="hl weak">
          <span class="hk">vs the latest month ({monYr(fc!.last.date)})</span>
          <span class="hv">{sg(cur.vsLatest)}</span>
          <span class="hn">{meta.adj === 'NSA' ? `Across the 12 months ahead this swings from ${sg(cur.lo)} to ${sg(cur.hi)}: mostly the season.` : 'Fine for seasonally adjusted data.'}</span>
        </div>
        <div class="hl good">
          <span class="hk">vs the same month a year earlier ({monYr(cur.ly.date)})</span>
          <span class="hv">{sg(cur.vsLY)}</span>
          <span class="hn">Across the 12 months ahead: {sg(cur.loLY)} to {sg(cur.hiLY)}. Like with like.</span>
        </div>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="cv"></div>
</Explorable>

<style>
  .cv { min-height: 260px; }
  .rd { display: flex; flex-direction: column; gap: .8rem; font-size: .84rem; }
  .hl { display: flex; flex-direction: column; gap: .1rem; padding: .55rem .7rem; border-radius: 8px; border: 1px solid var(--border); background: var(--bg-2); }
  .hl.weak { border-left: 3px solid var(--muted); }
  .hl.good { border-left: 3px solid var(--c-actual); }
  .hk { font-size: .76rem; color: var(--muted); }
  .hv { font: 650 1.3rem/1.2 var(--font-ui); font-variant-numeric: tabular-nums; color: var(--text); }
  .hn { font-size: .76rem; color: var(--text-2); }
</style>
