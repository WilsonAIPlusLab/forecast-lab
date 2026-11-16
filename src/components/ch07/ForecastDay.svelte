<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, type Pt } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import './viz';

  // What is actually known on forecast day? Weekly claims are released the Thursday after each week ends;
  // the jobs report for a month comes out on the third Friday after the week containing the 12th.
  // The explorer shows which weekly readings (assigned to a month by their week-ending Saturday, as
  // fred(to = "month") does) are already public on the chosen day, and what the honest monthly average is.
  const DAY = 864e5;
  const addD = (d: Date, k: number) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + k);
  const same = (a: Date, b: Date) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
  const md = (d: Date) => d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  const wmd = (d: Date) => d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' });
  const mName = (y: number, m: number) => new Date(y, m, 1).toLocaleDateString('en-US', { month: 'long' });
  const mYear = (y: number, m: number) => new Date(y, m, 1).toLocaleDateString('en-US', { month: 'short', year: 'numeric' });

  /** Usual claims release: the Thursday after the week-ending Saturday; Wednesday when that Thursday is a holiday. */
  function claimsRelease(sat: Date) {
    const thu = addD(sat, 5);
    const thanksgiving = thu.getMonth() === 10 && thu.getDate() >= 22 && thu.getDate() <= 28;
    const xmasNy = (thu.getMonth() === 11 && thu.getDate() === 25) || (thu.getMonth() === 0 && thu.getDate() === 1);
    return thanksgiving || xmasNy ? addD(thu, -1) : thu;
  }
  /** Reference week of the payroll survey: the Sunday–Saturday week that contains the 12th. */
  function refWeek(y: number, m: number) {
    const d12 = new Date(y, m, 12);
    const sat = addD(d12, 6 - d12.getDay());
    return { sun: addD(sat, -6), sat };
  }
  /** Usual jobs-report date: third Friday after the reference week; moved a week after New Year, a day before July 4. */
  function jobsRelease(y: number, m: number) {
    let r = addD(refWeek(y, m).sat, 20);
    if (r.getMonth() === 0 && r.getDate() <= 3) r = addD(r, 7);
    if (r.getMonth() === 6 && (r.getDate() === 3 || r.getDate() === 4)) r = addD(r, -1);
    return r;
  }

  const FIRST = { y: 2014, m: 0 }, LAST = { y: 2024, m: 11 };
  const NM = (LAST.y - FIRST.y) * 12 + LAST.m - FIRST.m + 1;
  let mi = $state((2020 - FIRST.y) * 12 + 2);    // March 2020
  let day = $state(19);                           // March 20
  let weekly: Pt[] = $state([]);
  let el: HTMLDivElement;

  onMount(() => {
    (async () => { weekly = (await loadSeries('ICSA', { start: '2013-11-01', end: '2025-02-28' })).data; })();
    return watchLayout(el, draw);
  });

  const ym = $derived({ y: FIRST.y + Math.floor((FIRST.m + mi) / 12), m: (FIRST.m + mi) % 12 });
  const start = $derived(new Date(ym.y, ym.m, 1));
  const relT = $derived(jobsRelease(ym.y, ym.m));
  const prev = $derived(ym.m === 0 ? { y: ym.y - 1, m: 11 } : { y: ym.y, m: ym.m - 1 });
  const relPrev = $derived(jobsRelease(prev.y, prev.m));
  const nDays = $derived(Math.round((+relT - +start) / DAY) + 2);
  // When the month changes, keep the slider inside the new range.
  $effect(() => { if (day > nDays) day = nDays; });
  const today = $derived(addD(start, day));

  const weeks = $derived(weekly.filter((p) => p.date.getFullYear() === ym.y && p.date.getMonth() === ym.m)
    .map((p) => ({ sat: p.date, sun: addD(p.date, -6), value: p.value, rel: claimsRelease(p.date) }))
    .map((w) => ({ ...w, known: +w.rel <= +today })));
  const known = $derived(weeks.filter((w) => w.known));
  const avg = (v: { value: number }[]) => v.reduce((a, w) => a + w.value, 0) / v.length;
  const lastRel = $derived(weeks.length ? weeks[weeks.length - 1].rel : null);
  const jobsKnown = $derived(+relT <= +today ? ym : +relPrev <= +today ? prev : (prev.m === 0 ? { y: prev.y - 1, m: 11 } : { y: prev.y, m: prev.m - 1 }));

  function draw() {
    if (!el || !weeks.length) return;
    const W = el.clientWidth;
    const accent = getComputedStyle(el).getPropertyValue('--ch').trim() || C.s[3];
    const x0 = addD(weeks[0].sun < start ? weeks[0].sun : start, -1), x1 = addD(relT, 3);
    const rw = refWeek(ym.y, ym.m);
    const next = new Date(ym.y, ym.m + 1, 1);
    const k = (v: number) => (v >= 1e6 ? (v / 1e6).toFixed(2) + 'M' : Math.round(v / 1000) + 'k');
    const lab = { fontSize: 12, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' } as any;
    const narrow = W < 520;
    const chart = Plot.plot({
      width: W, height: 250, marginLeft: 10, marginRight: 10, marginTop: 30, marginBottom: 30, style: plotStyle(),
      x: { type: 'time', domain: [x0, x1], label: null, ticks: narrow ? 4 : 7, tickFormat: (d: Date) => md(d) },
      y: { domain: [0, 4], axis: null },
      marks: [
        // month boundaries
        Plot.ruleX([start, next].filter((d) => d >= x0 && d <= x1), { stroke: C.borderStrong, strokeDasharray: '2 3' }),
        Plot.text([start], { x: (d: Date) => d, y: 4, text: () => `${mName(ym.y, ym.m)}${narrow ? '' : ' begins'}`, textAnchor: 'start', dx: 3, fill: C.muted, ...lab }),
        Plot.text([next].filter((d) => d <= x1), { x: (d: Date) => d, y: 4, text: () => `${mName(next.getFullYear(), next.getMonth())}${narrow ? '' : ' begins'}`, textAnchor: 'end', dx: -3, fill: C.muted, ...lab }),
        // weekly claims for weeks ending in month t
        Plot.text([x0], { x: (d: Date) => d, y: 3.55, text: () => `Weekly claims, weeks ending in ${mName(ym.y, ym.m)}`, textAnchor: 'start', dx: 2, fill: C.text, fontWeight: 650, ...lab }),
        Plot.rect(weeks, { x1: 'sun', x2: (w: any) => addD(w.sat, 1), y1: 2.35, y2: 3.25, inset: 1.5, fill: (w: any) => (w.known ? C.s[0] : 'none'), fillOpacity: 0.3, stroke: (w: any) => (w.known ? C.s[0] : C.muted), strokeDasharray: (w: any) => (w.known ? null : '4 3') } as any),
        Plot.text(weeks, { x: (w: any) => new Date((+w.sun + +addD(w.sat, 1)) / 2), y: 2.8, text: (w: any) => (w.known ? k(w.value) : '?'), fill: (w: any) => (w.known ? C.text : C.muted), fontWeight: 700, fontSize: 12 }),
        // publication lag: from the end of each week to its release
        Plot.link(weeks, { x1: (w: any) => addD(w.sat, 1), y1: 2.35, x2: 'rel', y2: 1.95, stroke: C.muted, strokeOpacity: 0.7, markerEnd: 'arrow' } as any),
        Plot.dot(weeks, { x: 'rel', y: 1.95, r: 3, fill: (w: any) => (w.known ? C.s[0] : C.surface), stroke: C.s[0] }),
        // payroll survey week and jobs reports
        Plot.rect([rw], { x1: 'sun', x2: (r: any) => addD(r.sat, 1), y1: 0.55, y2: 1.15, fill: C.s[2], fillOpacity: 0.25, stroke: C.s[2] }),
        Plot.text([rw], { x: (r: any) => r.sun, y: 1.4, text: () => (narrow ? 'Payroll survey week' : `Payroll survey week (contains the 12th)`), textAnchor: 'start', fill: C.text, fontWeight: 650, ...lab }),
        Plot.dot([relPrev, relT].filter((d) => d >= x0), { x: (d: Date) => d, y: 0.85, symbol: 'diamond', r: 6, fill: (d: Date) => (+d <= +today ? C.s[2] : C.surface), stroke: C.s[2], strokeWidth: 1.5 }),
        Plot.text([relT], { x: (d: Date) => d, y: 0.25, text: () => `${mName(ym.y, ym.m).slice(0, 3)} jobs report`, textAnchor: 'end', fill: C.text, ...lab }),
        Plot.text([relPrev].filter((d) => d >= x0), { x: (d: Date) => d, y: 0.25, text: () => `${mName(prev.y, prev.m).slice(0, 3)} report`, textAnchor: 'start', fill: C.muted, ...lab }),
        // forecast day
        Plot.ruleX([today], { stroke: accent, strokeWidth: 2.5 }),
        Plot.text([today], { x: (d: Date) => d, y: 4, text: () => 'forecast day', textAnchor: 'middle', dy: -16, fill: accent, fontWeight: 700, ...lab }),
        Plot.tip(weeks, Plot.pointerX({ x: (w: any) => new Date((+w.sun + +addD(w.sat, 1)) / 2), y: 2.8, title: (w: any) => `Week ${md(w.sun)}–${md(w.sat)}\nclaims: ${Math.round(w.value).toLocaleString('en-US')} (SA)\nreleased ${wmd(w.rel)}` })),
      ],
    });
    chart.setAttribute('aria-label', `Timeline for ${mYear(ym.y, ym.m)}: ${known.length} of ${weeks.length} weekly claims readings published by ${wmd(today)}`);
    el.replaceChildren(chart);
  }
  $effect(() => { weeks; today; draw(); });

  const th = (v: number) => (v >= 1e6 ? (v / 1e6).toFixed(2) + ' million' : Math.round(v / 1000).toLocaleString('en-US') + 'k');
</script>

<Explorable title="On forecast day, what do you actually know?" caption={`Pick a target month and slide the forecast day. Filled weeks are weekly claims readings already published on that day; dashed weeks are still in the future. Arrows run from the end of each week to its release (the Thursday after, about 5 days later). A week belongs to the month in which it <b>ends</b>, which is how <code>fred("ICSA", to = "month")</code> builds monthly averages. Diamonds are jobs reports. Dates follow the usual release rules (holiday shifts approximated; a few actual dates differ). Claims values are today's revised, seasonally adjusted figures; the numbers first published were somewhat different. Data: FRED (ICSA).`}>
  {#snippet controls()}
    <label class="sl">Target month <input type="range" min="0" max={NM - 1} step="1" bind:value={mi} aria-label="Target month" aria-valuetext={mYear(ym.y, ym.m)} /> <b>{mYear(ym.y, ym.m)}</b></label>
    <label class="sl">Forecast day <input type="range" min="0" max={nDays} step="1" bind:value={day} aria-label="Forecast day" aria-valuetext={wmd(today)} /> <b>{md(today)}</b></label>
  {/snippet}
  {#snippet aside()}
    {#if weeks.length}
      <div class="ro" aria-live="polite">
        <div class="stat"><span class="stat-v">{known.length} of {weeks.length}</span><span class="stat-l">weekly claims readings for {mName(ym.y, ym.m)} out by {wmd(today)}</span></div>
        <div class="stat"><span class="stat-v">{known.length ? th(avg(known)) : '—'}</span><span class="stat-l">claims a week, average of what is known so far</span></div>
        <div class="stat"><span class="stat-v">{th(avg(weeks))}</span><span class="stat-l">full-month average, complete on {lastRel ? md(lastRel) : ''}</span></div>
        <p class="v">
          Latest jobs report out: <b>{mName(jobsKnown.y, jobsKnown.m)}</b>.
          {#if known.length < weeks.length}
            Using {mName(ym.y, ym.m)}'s full claims average on this day would be <b>look-ahead bias</b>: {weeks.length - known.length} of its weeks are not yet published.
          {:else if +relT > +today}
            All of {mName(ym.y, ym.m)}'s claims are public before its jobs report ({md(relT)}). Using them now is a legitimate <b>nowcast</b>.
          {:else}
            The {mName(ym.y, ym.m)} jobs report is out: there is nothing left to forecast, only a first estimate that will be revised.
          {/if}
        </p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart" role="img" aria-label="Timeline of weekly claims releases and jobs reports around the target month"></div>
</Explorable>

<style>
  .chart { min-height: 250px; }
  .ro { display: flex; flex-direction: column; gap: .7rem; font-size: .84rem; }
  .v { margin: 0; color: var(--text-2); }
</style>
