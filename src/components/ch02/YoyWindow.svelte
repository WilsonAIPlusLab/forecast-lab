<script lang="ts">
  // Year-over-year growth is the last 12 seasonally adjusted monthly moves added up (compounded).
  // Scrub through the months to see why it turns late and why it echoes last year's shocks (base effects).
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, ym } from '../../lib/ts';
  import { C, watchLayout } from '../../lib/viz/theme';

  type Row = { date: Date; nsa: number; sa: number; mom: number | null; yoy: number | null; yoyN: number | null };
  let rows: Row[] = $state([]);
  let i = $state(0);
  let minI = $state(12);
  let el: HTMLDivElement;

  onMount(async () => {
    const [r, a, f] = await Promise.all([loadSeries('RSXFSN', { start: '2014-01-01' }), loadSeries('RSAFS', { start: '2014-01-01' }), loadSeries('RSFSDP', { start: '2014-01-01' })]);
    const k = (d: Date) => `${d.getFullYear()}-${d.getMonth()}`;
    const am = new Map(a.data.map((p) => [k(p.date), p.value]));
    const fm = new Map(f.data.map((p) => [k(p.date), p.value]));
    const base = r.data.filter((p) => am.has(k(p.date)) && fm.has(k(p.date))).map((p) => ({ date: p.date, nsa: p.value, sa: am.get(k(p.date))! - fm.get(k(p.date))! }));
    rows = base.map((x, j) => ({
      ...x,
      mom: j >= 1 ? 100 * (x.sa / base[j - 1].sa - 1) : null,          // SA month-over-month, %
      yoy: j >= 12 ? 100 * (x.sa / base[j - 12].sa - 1) : null,        // SA year-over-year, %
      yoyN: j >= 12 ? 100 * (x.nsa / base[j - 12].nsa - 1) : null,     // raw (NSA) year-over-year, %
    }));
    minI = rows.findIndex((x) => x.date.getFullYear() === 2016);
    const dec = rows.map((x, j) => (x.date.getMonth() === 11 ? j : -1)).filter((j) => j >= 0);
    i = dec[dec.length - 1];
  });

  const find = (y: number, m: number) => rows.findIndex((x) => x.date.getFullYear() === y && x.date.getMonth() === m);
  const jumps = [{ t: 'Apr 2020', y: 2020, m: 3 }, { t: 'Apr 2021', y: 2021, m: 3 }, { t: 'Latest', y: 0, m: 0 }];
  const f1 = (x: number) => (Number.isFinite(x) ? (x > 0 ? '+' : x < 0 ? '−' : '') + Math.abs(x).toFixed(1) + '%' : 'n/a');
  const label = (d: Date) => d.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });

  const v = $derived.by(() => {
    if (!rows.length || i < 12) return null;
    const r = rows[i];
    const own = r.mom as number;
    const older = 100 * (rows[i - 1].sa / rows[i - 12].sa - 1);   // the 11 months before this one, compounded
    const recent3 = 100 * (r.sa / rows[i - 3].sa - 1);            // last three months, compounded
    return { r, own, older, recent3, yoy: r.yoy as number, yoyN: r.yoyN as number };
  });

  const style = () => ({ background: 'transparent', color: C.muted, fontSize: '12px', fontFamily: 'var(--font-ui)', overflow: 'visible' as const });
  function draw() {
    if (!el || !v) return;
    const W = el.clientWidth;
    const data = rows.slice(minI);
    const inWin = (d: Row) => d.date <= v.r.date && d.date > rows[i - 12].date;
    const common = { width: W, marginLeft: 50, marginRight: 14, style: style() };
    const clipY = (x: number) => Math.max(-6, Math.min(6, x));
    const p1 = Plot.plot({
      ...common, height: 180, marginTop: 18, marginBottom: 6, x: { axis: null }, y: { grid: true, ticks: 5, label: 'year over year, %', tickFormat: (d: number) => `${d > 0 ? '+' : ''}${d}` },
      marks: [
        Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
        Plot.lineY(data, { x: 'date', y: 'yoy', stroke: C.forecast, strokeWidth: 2.4 }),
        Plot.dot([v.r], { x: 'date', y: 'yoy', r: 5, fill: C.actual, stroke: C.text, strokeWidth: 1 }),
        Plot.text([v.r], { x: 'date', y: 'yoy', text: (d: any) => `YoY ${f1(d.yoy)}`, dy: -12, textAnchor: v.r.date > data[Math.floor(data.length * 0.75)].date ? 'end' : 'start', fill: C.text, fontWeight: 700, fontSize: 12 }),
        Plot.tip(data, Plot.pointerX({ x: 'date', y: 'yoy', title: (d: any) => `${ym(d.date)}\nYear over year (SA): ${f1(d.yoy)}\nYear over year (raw): ${f1(d.yoyN)}` })),
      ],
    });
    const p2 = Plot.plot({
      ...common, height: 170, marginTop: 24, marginBottom: 26, x: { label: null }, y: { grid: true, ticks: 5, domain: [-6, 6], label: 'month over month, SA, %', tickFormat: (d: number) => `${d > 0 ? '+' : ''}${d}` },
      marks: [
        Plot.rectX([{ a: new Date(+rows[i - 11].date - 15 * 864e5), b: new Date(+v.r.date + 15 * 864e5) }], { x1: 'a', x2: 'b', fill: C.actual, fillOpacity: 0.12 }),
        Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
        Plot.ruleX(data, { x: 'date', y1: 0, y2: (d: Row) => clipY(d.mom as number), stroke: (d: Row) => (inWin(d) ? C.actual : C.s[1]), strokeWidth: (d: Row) => (inWin(d) ? 3 : 1.5), strokeOpacity: (d: Row) => (inWin(d) ? 1 : 0.45) }),
        Plot.tip(data, Plot.pointerX({ x: 'date', y: (d: Row) => clipY(d.mom as number), title: (d: any) => `${ym(d.date)}\nMonth over month (SA): ${f1(d.mom)}` })),
      ],
    });
    p1.setAttribute('aria-label', 'Year-over-year growth of seasonally adjusted retail sales, with the selected month marked');
    p2.setAttribute('aria-label', 'Seasonally adjusted month-over-month growth; the 12 months that make up the selected year-over-year change are highlighted');
    el.replaceChildren(p1, p2);
  }
  $effect(() => { v; draw(); });
  onMount(() => watchLayout(el, draw));
</script>

<Explorable title="Year-over-year growth is twelve months of news, not one" caption="Top: growth versus the same month a year earlier. Bottom: seasonally adjusted month-over-month changes (bars clipped at ±6% so ordinary months stay visible; hover for exact values). The 12 gold bars in the shaded window multiply together to give the year-over-year figure above. Jump to April 2021: sales barely moved that month, yet the year-over-year rate was enormous, because April 2020 was the lockdown low. Data: U.S. retail sales excl. food services, Census SA (RSAFS − RSFSDP) and NSA (RSXFSN), via FRED.">
  {#snippet controls()}
    {#if rows.length}
      <label class="sl">Month <input type="range" min={minI} max={rows.length - 1} bind:value={i} aria-label="Month whose year-over-year growth to explain" aria-valuetext={label(rows[i].date)} /> <b class="wide">{label(rows[i].date)}</b></label>
      <div class="seg" role="group" aria-label="Jump to a month">
        {#each jumps as j}
          <button onclick={() => (i = j.y ? find(j.y, j.m) : rows.length - 1)}>{j.t}</button>
        {/each}
      </div>
    {/if}
  {/snippet}
  {#snippet aside()}
    {#if v}
      <div class="ro">
        <div class="stack">
          <div class="ln"><span>This month’s own move</span><b>{f1(v.own)}</b></div>
          <div class="ln"><span>× the 11 months before it</span><b>{f1(v.older)}</b></div>
          <div class="ln tot"><span>= year over year (SA)</span><b>{f1(v.yoy)}</b></div>
        </div>
        <p class="note">{Math.abs(v.older) > 3 * Math.max(0.5, Math.abs(v.own)) ? `Most of this year-over-year figure is old news: the 11 earlier months contribute ${f1(v.older)}, this month only ${f1(v.own)}.` : `This month's own move is a sizable part of the year-over-year figure.`} The last three months alone: {f1(v.recent3)}.</p>
        <p class="note small">Raw (NSA) year over year: <b>{f1(v.yoyN)}</b>. Comparing a month with the same month a year earlier cancels most seasonality, but not differences in trading days or holiday timing between the two years.</p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart" aria-label="Year-over-year and month-over-month growth of retail sales"></div>
</Explorable>

<style>
  .chart { min-height: 350px; }
  .ro { display: grid; gap: .8rem; font-size: .82rem; }
  .stack { display: grid; gap: .3rem; font-variant-numeric: tabular-nums; }
  .ln { display: flex; justify-content: space-between; gap: .6rem; color: var(--text-2); }
  .ln b { font: 650 1rem var(--font-ui); color: var(--text); }
  .ln.tot { border-top: 1px solid var(--border-strong); padding-top: .3rem; color: var(--text); font-weight: 650; }
  .ln.tot b { font-size: 1.2rem; }
  .note { margin: 0; color: var(--text-2); line-height: 1.5; }
  .note.small { font-size: .78rem; color: var(--muted); border-top: 1px solid var(--border); padding-top: .6rem; }
  .wide { min-width: 9.5rem !important; font-family: var(--font-ui) !important; }
</style>
