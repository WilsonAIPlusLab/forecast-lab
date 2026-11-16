<script lang="ts">
  // Spread reader: one row of the recession data set, taken apart.
  // Left: the month's yield curve (3-month bill and 10-year bond, % per year) with the spread measured in
  // percentage points and basis points. Right: a timeline from the month the spread is observed to the month
  // the target asks about (12 months later), with NBER recessions shaded. Panel: the full-sample logit's
  // probability in words, odds, against the base rate, and what a 0.25-point or 1-point steeper curve would change.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, css, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { loadSeries } from '../../lib/ts';
  import { loadRecData, recessionSpans, fitLogit, sigmoid, mon, type Row } from './model';

  let rows: Row[] = $state.raw([]);
  let lev: { g: number; t: number }[] = $state.raw([]);
  let spans: { a: Date; b: Date }[] = $state.raw([]);
  let fit = $state.raw({ a: 0, b: 0 });
  let base = $state(0);
  let i = $state(0);
  let elA: HTMLDivElement, elB: HTMLDivElement;

  const PRESETS = [
    { k: '2023-4', label: 'May 2023 (deepest inversion)' },
    { k: '2007-0', label: 'Jan 2007' },
    { k: '1980-2', label: 'Mar 1980' },
    { k: 'last', label: 'Latest month' },
  ];
  const keyOf = (d: Date) => `${d.getFullYear()}-${d.getMonth()}`;
  function jump(k: string) { const j = k === 'last' ? rows.length - 1 : rows.findIndex((r) => keyOf(r.date) === k); if (j >= 0) i = j; }

  onMount(() => {
    let stopA = () => {}, stopB = () => {};
    Promise.all([loadRecData(), loadSeries('GS10', { start: '1959-01-01' }), loadSeries('TB3MS', { start: '1959-01-01' }), recessionSpans()]).then(([rs, g, t, sp]) => {
      const gm = new Map(g.data.map((p) => [keyOf(p.date), p.value])), tm = new Map(t.data.map((p) => [keyOf(p.date), p.value]));
      lev = rs.map((r) => ({ g: gm.get(keyOf(r.date))!, t: tm.get(keyOf(r.date))! }));
      const known = rs.filter((r) => r.ahead !== null);
      const f = fitLogit(known.map((r) => r.spread), known.map((r) => r.ahead!));
      fit = { a: f.a, b: f.b };
      base = known.reduce((s, r) => s + r.ahead!, 0) / known.length;
      spans = sp; rows = rs;
      i = rs.findIndex((r) => keyOf(r.date) === '2023-4');
      stopA = watchLayout(elA, draw); stopB = watchLayout(elB, draw);
    });
    return () => { stopA(); stopB(); };
  });

  const row = $derived(rows[i]);
  const L = $derived(lev[i]);
  const pr = (s: number) => sigmoid(fit.a + fit.b * s);
  const p = $derived(row ? pr(row.spread) : 0);
  const pQ = $derived(row ? pr(row.spread + 0.25) : 0);
  const p1 = $derived(row ? pr(row.spread + 1) : 0);
  const odds = (q: number) => (q >= 0.5 ? `${(q / (1 - q)).toFixed(2)} to 1` : `1 to ${((1 - q) / q).toFixed(1)}`);
  const sgn = (v: number, d = 1) => `${v >= 0 ? '+' : '−'}${Math.abs(v).toFixed(d)}`;
  const outcome = $derived(!row ? '' : row.ahead === null ? 'not known yet: this is a real forecast' : row.ahead ? 'yes, a recession month' : 'no recession');

  function draw() {
    if (!elA || !elB || !row || !L) return;
    // A: the yield curve on the chosen month (two maturities)
    const WA = elA.clientWidth, WB = elB.clientWidth;
    if (WA < 150 || WB < 150) return; // skip transient zero-width layouts
    const top = Math.max(L.g, L.t, 1) + 1.5;
    const pts = [{ m: '3-month bill', v: L.t }, { m: '10-year bond', v: L.g }];
    const inv = row.spread < 0;
    const a = Plot.plot({
      width: WA, height: 250, marginLeft: 40, marginRight: 20, marginTop: 22, marginBottom: 34, style: plotStyle(),
      x: { domain: pts.map((d) => d.m), label: null, padding: 0.45 },
      y: { domain: [0, Math.ceil(top)], grid: true, label: '↑ Yield (% per year)' },
      marks: [
        Plot.line(pts, { x: 'm', y: 'v', stroke: inv ? C.danger : C.history, strokeWidth: 2.5 }),
        Plot.dot(pts, { x: 'm', y: 'v', r: 6, fill: inv ? C.danger : C.history, stroke: C.surface, strokeWidth: 2 }),
        Plot.text(pts, { x: 'm', y: 'v', text: (d: any) => `${d.v.toFixed(2)}%`, dy: -14, fill: C.text, fontSize: 12, fontWeight: 650, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
        Plot.ruleY([0], { stroke: C.borderStrong }),
      ],
    });
    a.setAttribute('aria-label', `Yield curve in ${mon(row.date)}: 3-month bill ${L.t.toFixed(2)} percent, 10-year bond ${L.g.toFixed(2)} percent, spread ${row.spread.toFixed(2)} percentage points.`);
    elA.replaceChildren(a);

    // B: timeline from the observed month to the target month
    const t0 = new Date(row.date), tT = new Date(row.target);
    const lo = new Date(t0.getFullYear(), t0.getMonth() - 18, 1), hi = new Date(t0.getFullYear(), t0.getMonth() + 24, 1);
    const win = rows.filter((r) => r.date >= lo && r.date <= hi);
    const sp = spans.filter((s) => +s.b >= +lo && +s.a <= +hi).map((s) => ({ a: s.a < lo ? lo : s.a, b: s.b > hi ? hi : s.b }));
    const ext = win.length ? [Math.min(-1, ...win.map((r) => r.spread)) - 0.4, Math.max(1, ...win.map((r) => r.spread)) + 1.1] : [-3, 5];
    const tcol = row.ahead === null ? C.muted : row.ahead ? C.danger : C.good;
    const b = Plot.plot({
      width: WB, height: 250, marginLeft: 40, marginRight: 20, marginTop: 22, marginBottom: 34, style: plotStyle(),
      x: { domain: [lo, hi], type: 'time', label: null, ticks: WB < 420 ? 3 : 6 },
      y: { domain: ext, grid: true, label: '↑ Spread (percentage points)' },
      marks: [
        Plot.rectX(sp, { x1: 'a', x2: 'b', y1: ext[0], y2: ext[1], fill: C.muted, fillOpacity: 0.18 }),
        Plot.ruleY([0], { stroke: C.borderStrong }),
        Plot.lineY(win, { x: 'date', y: 'spread', stroke: C.history, strokeWidth: 2 }),
        Plot.ruleX([tT], { stroke: tcol, strokeWidth: 2.5 }),
        Plot.arrow([{ x1: t0, x2: tT, y: ext[1] - 0.45 }], { x1: 'x1', x2: 'x2', y1: 'y', y2: 'y', stroke: C.forecast, strokeWidth: 2, headLength: 9 }),
        Plot.text([{ x: new Date((+t0 + +tT) / 2), y: ext[1] - 0.45 }], { x: 'x', y: 'y', text: () => '12 months', dy: -9, fill: C.forecast, fontSize: 12, fontWeight: 650 }),
        Plot.dot([{ x: t0, y: row.spread }], { x: 'x', y: 'y', r: 7, fill: C.actual, stroke: C.surface, strokeWidth: 2 }),
        Plot.text([{ x: tT, y: ext[0] }], { x: 'x', y: 'y', text: () => (row.ahead === null ? 'target: ?' : row.ahead ? 'target: 1' : 'target: 0'), dy: -8, dx: 5, textAnchor: 'start', fill: tcol, fontSize: 12, fontWeight: 700, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
      ],
    });
    b.setAttribute('aria-label', `Spread from ${mon(lo)} to ${mon(hi)} with recessions shaded. The spread is observed in ${mon(t0)}; the target asks whether ${mon(tT)} is a recession month: ${outcome}.`);
    elB.replaceChildren(b);
  }
  $effect(() => { i; rows; draw(); });
</script>

<Explorable title="One row of the data: today's spread, next year's answer" caption="Pick a month. <b>Left:</b> that month's yield curve, the 3-month Treasury bill and the 10-year Treasury bond, both monthly averages in % per year; red means inverted. The spread is the 10-year minus the 3-month yield, so it is measured in <b>percentage points</b> (1 point = 100 basis points), not in percent. <b>Right:</b> the gold dot is the spread you know today; the violet arrow jumps 12 months ahead to the month the target asks about (grey bands are NBER recessions). The row pairs those two months, which is exactly what shifting <code>USREC</code> by 12 does. The panel reads the full-sample logit (fitted on 802 months) in words. Data: FRED GS10, TB3MS, USREC.">
  {#snippet controls()}
    <label class="sl">Month <input type="range" min="0" max={Math.max(0, rows.length - 1)} step="1" bind:value={i} aria-valuetext={row ? mon(row.date) : ''} disabled={!rows.length} /> <b>{row ? mon(row.date) : '…'}</b></label>
    <div class="seg" role="group" aria-label="Jump to a month">
      {#each PRESETS as x}<button onclick={() => jump(x.k)} disabled={!rows.length}>{x.label}</button>{/each}
    </div>
  {/snippet}
  {#snippet aside()}
    {#if row && L}
      <div class="side" aria-live="polite">
        <div class="eyebrow">The row for {mon(row.date)}</div>
        <p class="eq">{L.g.toFixed(2)}% − {L.t.toFixed(2)}% = <b>{sgn(row.spread, 2)} points</b> <span class="muted">({sgn(100 * row.spread, 0)} basis points)</span></p>
        <p class="words">Target: is <b>{mon(row.target)}</b> a recession month? <span class:yes={row.ahead === 1} class:no={row.ahead === 0}>{outcome}</span>.</p>
        <div class="stat"><span class="stat-v">{(100 * p).toFixed(1)}%</span><span class="stat-l">chance of recession in {mon(row.target)} · odds {odds(p)} · {(p / base).toFixed(1)}× the {(100 * base).toFixed(1)}% base rate</span></div>
        <p class="words">If the curve were <b>a quarter point (25 bp) steeper</b>: {(100 * pQ).toFixed(1)}% ({sgn(100 * (pQ - p))} pp). <b>One full point (100 bp) steeper</b>: {(100 * p1).toFixed(1)}% ({sgn(100 * (p1 - p))} pp). The odds ratio, {Math.exp(fit.b).toFixed(2)} per point, is the same in every month; the percentage-point change is not.</p>
      </div>
    {:else}<p class="muted">Loading FRED data…</p>{/if}
  {/snippet}
  <div class="two">
    <div bind:this={elA} class="chart"></div>
    <div bind:this={elB} class="chart"></div>
  </div>
</Explorable>

<style>
  .two { display: grid; grid-template-columns: minmax(0, 2fr) minmax(0, 3fr); gap: 1rem; }
  @media (max-width: 640px) { .two { grid-template-columns: 1fr; } }
  .chart { min-height: 250px; min-width: 0; }
  .side { display: grid; gap: .7rem; font-size: .84rem; }
  .eyebrow { font-size: .74rem; font-weight: 700; color: var(--muted); text-transform: uppercase; letter-spacing: .04em; }
  .eq { margin: 0; font: 600 .86rem var(--font-mono); color: var(--text); }
  .eq .muted { font-weight: 400; color: var(--muted); }
  .words { margin: 0; color: var(--text-2); line-height: 1.5; }
  .yes { color: var(--danger); font-weight: 650; }
  .no { color: var(--good); font-weight: 650; }
  .muted { color: var(--muted); }
</style>
