<script lang="ts">
  // Log ruler: pick two months on the oil price and compare the percent change with the log change.
  // One idea: for small moves the two agree (0.01 in logs is about 1%); for big moves they part ways,
  // and only log changes are symmetric (down 124 log points, then up 124, gets you back).
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, type Pt } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { monthLabel, mkey, signed } from './util';

  let pts: Pt[] = $state([]);
  let a = $state(0);          // index of month A
  let b = $state(0);          // index of month B
  let scale: 'linear' | 'log' = $state('linear');
  let el: HTMLDivElement;

  onMount(() => {
    // WTI crude oil, $ per barrel, daily -> monthly averages (no negative monthly averages, so logs are defined)
    loadSeries('DCOILWTICO', { to: 'month', start: '2000-01-01' }).then((s) => {
      pts = s.data;
      const ia = pts.findIndex((p) => mkey(p.date) === '2008-06');
      const ib = pts.findIndex((p) => mkey(p.date) === '2009-02');
      a = ia >= 0 ? ia : 0; b = ib >= 0 ? ib : pts.length - 1;
    });
    return watchLayout(el, draw);
  });

  const A = $derived(pts[a]);
  const B = $derived(pts[b]);
  const pct = $derived(A && B ? 100 * (B.value / A.value - 1) : NaN);        // percent change A -> B
  const lg = $derived(A && B ? 100 * Math.log(B.value / A.value) : NaN);     // log change x 100 ("log points")
  const back = $derived(A && B ? 100 * (A.value / B.value - 1) : NaN);       // percent change needed to return B -> A
  const gap = $derived(lg - pct);
  const months = $derived(b - a);

  function verdict(): string {
    if (!Number.isFinite(pct)) return '';
    const ap = Math.abs(pct);
    if (ap < 0.05) return 'No change: both measures are zero.';
    if (ap <= 10) return `A small move: the two measures differ by only ${Math.abs(gap).toFixed(2)} points. This is why a log change of 0.01 reads as “about 1%”.`;
    if (ap <= 25) return `A medium move: the gap is ${Math.abs(gap).toFixed(1)} points. Still a fair approximation, but say which one you report.`;
    return `A big move: the two differ by ${Math.abs(gap).toFixed(0)} points. Report the percent change to readers, and use log changes for the arithmetic.`;
  }

  function draw() {
    if (!el || !pts.length || !A || !B) return;
    const W = Math.max(280, el.clientWidth || 600);   // floor guards against a transient zero-width layout
    const H = Math.max(280, Math.min(380, W * 0.5));
    const lo = Math.min(A.value, B.value), hi = Math.max(A.value, B.value);
    const ymin = Math.min(...pts.map((p) => p.value)), ymax = Math.max(...pts.map((p) => p.value));
    // put each label on the side away from the other marker, but never off the edge of the chart
    const n = Math.max(1, pts.length - 1);
    const aLeft = a / n > 0.2 && (a <= b || a / n > 0.8);
    const bLeft = b / n > 0.2 && (b < a || b / n > 0.8);
    const marks: any[] = [
      // band between the two prices: the size of the move on this axis
      Plot.rectY([0], { x1: () => pts[0].date, x2: () => pts[pts.length - 1].date, y1: () => lo, y2: () => hi, fill: C.actual, fillOpacity: 0.07 }),
      Plot.lineY(pts, { x: 'date', y: 'value', stroke: C.history, strokeWidth: 1.6 }),
      Plot.ruleY([A.value, B.value], { stroke: C.text2, strokeDasharray: '4 4', strokeWidth: 1 }),
      Plot.ruleX([A.date], { stroke: C.actual, strokeWidth: 2 }),
      Plot.ruleX([B.date], { stroke: C.forecast, strokeWidth: 2 }),
      Plot.dot([A], { x: 'date', y: 'value', r: 6, fill: C.actual, stroke: C.surface, strokeWidth: 2 }),
      Plot.dot([B], { x: 'date', y: 'value', r: 6, fill: C.forecast, stroke: C.surface, strokeWidth: 2 }),
      Plot.text([A], { x: 'date', y: 'value', text: (d: Pt) => `A  $${d.value.toFixed(0)}`, dx: aLeft ? -9 : 9, dy: -12, textAnchor: aLeft ? 'end' : 'start', fill: C.text, fontSize: 13, fontWeight: 650, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
      Plot.text([B], { x: 'date', y: 'value', text: (d: Pt) => `B  $${d.value.toFixed(0)}`, dx: bLeft ? -9 : 9, dy: 14, textAnchor: bLeft ? 'end' : 'start', fill: C.text, fontSize: 13, fontWeight: 650, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
      Plot.tip(pts, Plot.pointerX({ x: 'date', y: 'value', title: (d: Pt) => `${monthLabel(d.date)}\n$${d.value.toFixed(2)} per barrel\nlog = ${Math.log(d.value).toFixed(3)}` })),
    ];
    const chart = Plot.plot({
      width: W, height: H, marginLeft: 52, marginRight: 16, marginTop: 30,
      style: plotStyle(), x: { label: null },
      y: scale === 'log'
        // doubling ticks ($20, $40, $80): on a log axis each doubling is the same height
        ? { type: 'log', grid: true, label: '$ per barrel (log scale)', domain: [ymin * 0.95, ymax * 1.05], ticks: [20, 40, 80], tickFormat: (v: number) => `$${v}` }
        : { grid: true, label: '$ per barrel', tickFormat: (v: number) => `$${v}` },
      marks,
    });
    chart.setAttribute('role', 'img');
    chart.setAttribute('aria-label', `WTI crude oil price since 2000, ${scale} axis. Month A ${monthLabel(A.date)} at $${A.value.toFixed(0)}, month B ${monthLabel(B.date)} at $${B.value.toFixed(0)}: a ${signed(pct)}% change, or ${signed(lg)} log points.`);
    el.replaceChildren(chart);
  }

  $effect(() => { a; b; scale; pts; draw(); });
</script>

<Explorable title="Percent change or log change? They agree for small moves and split apart for big ones" caption={`Drag <b>A</b> and <b>B</b> to any two months of the oil price and compare the two ways of measuring the move. It opens on the 2008 crash. Then move B to one month after A: the numbers nearly match. Switch to the <b>log scale</b>: now equal percentage moves have equal heights, so a halving looks the same size in 2001 and in 2020. Data: FRED (DCOILWTICO), WTI crude oil, $ per barrel, monthly averages of daily prices, not seasonally adjusted.`}>
  {#snippet controls()}
    <label class="sl">A
      <input type="range" min="0" max={Math.max(0, pts.length - 1)} step="1" bind:value={a} aria-label="Month A" aria-valuetext={A ? monthLabel(A.date) : ''} />
      <b>{A ? monthLabel(A.date) : '…'}</b>
    </label>
    <label class="sl">B
      <input type="range" min="0" max={Math.max(0, pts.length - 1)} step="1" bind:value={b} aria-label="Month B" aria-valuetext={B ? monthLabel(B.date) : ''} />
      <b>{B ? monthLabel(B.date) : '…'}</b>
    </label>
    <div class="seg" role="group" aria-label="Price axis">
      <button class:on={scale === 'linear'} aria-pressed={scale === 'linear'} onclick={() => (scale = 'linear')}>Dollar axis</button>
      <button class:on={scale === 'log'} aria-pressed={scale === 'log'} onclick={() => (scale = 'log')}>Log scale</button>
    </div>
  {/snippet}
  {#snippet aside()}
    <div class="board" aria-live="polite">
      {#if A && B}
        <div class="pair">
          <div class="stat"><span class="stat-v pc">{signed(pct)}%</span><span class="stat-l">percent change, A to B</span></div>
          <div class="stat"><span class="stat-v lgc">{signed(lg)}</span><span class="stat-l">log change × 100 (“log points”)</span></div>
        </div>
        <p class="trip">To get from B <b>back</b> to A takes <b>{signed(back)}%</b>, but exactly <b>{signed(-lg)}</b> log points.{Math.abs(pct) > 25 ? ' Percent changes are lopsided; log changes are symmetric.' : ''}</p>
        <p class="what">{verdict()}</p>
        {#if months !== 0}<p class="hint">Over {Math.abs(months)} month{Math.abs(months) === 1 ? '' : 's'}. Convert back: B = A × e<sup>{(lg / 100).toFixed(3)}</sup> = ${(A.value * Math.exp(lg / 100)).toFixed(2)}.</p>{/if}
      {/if}
    </div>
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 280px; }
  .board { font-size: .86rem; line-height: 1.55; display: grid; gap: .7rem; }
  .pair { display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; }
  .pc { color: var(--accent-text); }
  .lgc { color: var(--c-fitted); }
  .trip, .what { margin: 0; color: var(--text-2); }
  .hint { margin: 0; color: var(--muted); font-size: .78rem; }
</style>
