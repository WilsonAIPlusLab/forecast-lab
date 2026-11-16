<script lang="ts">
  // Frequency zoom: aggregate a daily rate (the 10y–3m Treasury spread) or a weekly flow (initial
  // jobless claims) to lower frequencies, with a choice of aggregation rule.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, type Pt } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { monthLabel } from './util';

  type Sid = 'T10Y3M' | 'ICSA';
  type Freq = 'D' | 'W' | 'M' | 'Q';
  type How = 'mean' | 'last' | 'sum';
  const SERIES: Record<Sid, { label: string; native: Freq; kind: string }> = {
    T10Y3M: { label: '10y–3m spread (daily rate)', native: 'D', kind: 'rate' },
    ICSA: { label: 'Jobless claims (weekly flow)', native: 'W', kind: 'flow' },
  };
  const FREQS: { k: Freq; label: string }[] = [
    { k: 'D', label: 'Daily' }, { k: 'W', label: 'Weekly' }, { k: 'M', label: 'Monthly' }, { k: 'Q', label: 'Quarterly' },
  ];
  const HOWS: { k: How; label: string }[] = [
    { k: 'mean', label: 'Average' }, { k: 'last', label: 'End of period' }, { k: 'sum', label: 'Sum' },
  ];
  const START = new Date('2006-01-01T00:00:00');

  let sid = $state<Sid>('T10Y3M');
  let freq = $state<Freq>('M');
  let how = $state<How>('mean');
  let raw: Partial<Record<Sid, Pt[]>> = $state({});
  let rec: Date[] = $state([]);
  let el: HTMLDivElement;

  onMount(() => {
    Promise.all([loadSeries('T10Y3M'), loadSeries('ICSA'), loadSeries('USREC')]).then(([a, b, r]) => {
      raw = { T10Y3M: a.data.filter((p) => p.date >= START), ICSA: b.data.filter((p) => p.date >= START) };
      rec = r.data.filter((p) => p.value === 1 && p.date >= START).map((p) => p.date);
    });
    return watchLayout(el, draw);
  });

  // The period a date belongs to, identified by its first day (weeks end on Friday, as in FRED's weekly averages).
  function periodOf(d: Date, f: Freq): { start: Date; end: Date } {
    if (f === 'D') return { start: d, end: d };
    if (f === 'W') {
      const end = new Date(d); end.setDate(d.getDate() + ((5 - d.getDay() + 7) % 7));
      const start = new Date(end); start.setDate(end.getDate() - 6);
      return { start, end };
    }
    const m0 = f === 'M' ? d.getMonth() : Math.floor(d.getMonth() / 3) * 3;
    const start = new Date(d.getFullYear(), m0, 1);
    const end = new Date(d.getFullYear(), m0 + (f === 'M' ? 1 : 3), 0);
    return { start, end };
  }

  const agg = $derived.by(() => {
    const d = raw[sid];
    if (!d) return null;
    const native = SERIES[sid].native;
    const f: Freq = native === 'W' && freq === 'D' ? 'W' : freq;
    if (f === native) return { f, pts: d.map((p) => ({ date: p.date, value: p.value, n: 1, partial: false })) };
    const groups = new Map<number, { start: Date; end: Date; v: number[] }>();
    for (const p of d) {
      const per = periodOf(p.date, f);
      const k = +per.start;
      if (!groups.has(k)) groups.set(k, { ...per, v: [] });
      groups.get(k)!.v.push(p.value);
    }
    const last = d[d.length - 1].date;
    const slack = native === 'D' ? 3 : 6; // days: allow for weekends / week-ending dates
    const pts = [...groups.values()].map((g) => ({
      date: f === 'W' ? g.end : g.start,
      value: how === 'mean' ? g.v.reduce((a, b) => a + b, 0) / g.v.length : how === 'last' ? g.v[g.v.length - 1] : g.v.reduce((a, b) => a + b, 0),
      n: g.v.length,
      partial: (+g.end - +last) / 864e5 > slack,
    }));
    return { f, pts };
  });

  const unit = $derived(
    sid === 'T10Y3M'
      ? how === 'sum' && agg && agg.f !== 'D' ? 'pp × trading days (meaningless)' : 'percentage points'
      : how === 'sum' && agg && agg.f !== 'W' ? 'total initial claims in the period' : how === 'last' && agg && agg.f !== 'W' ? 'claims in the last week of the period' : 'initial claims per week'
  );

  const stats = $derived.by(() => {
    if (!agg) return null;
    const full = agg.pts.filter((p) => !p.partial);
    const lo = full.reduce((a, b) => (b.value < a.value ? b : a));
    const hi = full.reduce((a, b) => (b.value > a.value ? b : a));
    const inv = full.filter((p) => p.value < 0).length;
    return { n: full.length, lo, hi, inv, partial: agg.pts.some((p) => p.partial) };
  });

  const verdict = $derived.by(() => {
    if (!agg) return '';
    const native = agg.f === SERIES[sid].native;
    if (native) return sid === 'T10Y3M' ? 'Raw business-day data: every wiggle is visible, including one-day jumps that mean little on their own. Holidays are simply missing.' : 'Raw weekly data (seasonally adjusted). Each point is the number of new unemployment-insurance claims filed that week.';
    if (sid === 'T10Y3M') {
      if (how === 'mean') return '<b>Good choice for a rate.</b> The average uses every day in the period and smooths out one-day noise. This is what <code>fred(…, to = "month")</code> does.';
      if (how === 'last') return '<b>Also legitimate.</b> The end-of-period value is what markets quote, but it rests on a single day, so it is jumpier and can disagree with the average about whether the curve was inverted.';
      return '<b>Wrong for a rate.</b> Adding up daily yields gives a number that depends on how many trading days the period has. Look at the ragged pattern: it partly tracks the calendar, not the bond market.';
    }
    if (how === 'sum') return '<b>Right for a total, risky for comparisons.</b> The sum is the number of new claims filed in the period. But weeks are assigned by their end date, so some months get four weeks and some get five: the monthly sum jumps about 25% whenever a month gains a week, even if nothing changed.';
    if (how === 'mean') return '<b>Best for comparing months.</b> Average weekly claims are comparable across months with four or five weeks, which the sum is not. Use this when you study month-to-month changes.';
    return '<b>Throws information away.</b> The last week alone stands in for the whole period. Fine for a stock, wasteful for a flow.';
  });

  function draw() {
    if (!el || !agg) return;
    const W = el.clientWidth;
    const native = agg.f === SERIES[sid].native;
    const ctxOn = !native && how !== 'sum';
    const d = raw[sid]!;
    const full = agg.pts.filter((p) => !p.partial), part = agg.pts.filter((p) => p.partial);
    const step = agg.f === 'M' || agg.f === 'Q';
    const lbl = (p: any) => (agg.f === 'Q' ? `${p.date.getFullYear()} Q${Math.floor(p.date.getMonth() / 3) + 1}` : agg.f === 'M' ? monthLabel(p.date) : p.date.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' }));
    const fmtVal = (v: number) => (sid === 'T10Y3M' ? `${v.toFixed(2)} ${how === 'sum' && !native ? 'pp-days' : 'pp'}` : Math.round(v).toLocaleString('en-US') + ' claims');
    const chart = Plot.plot({
      width: W, height: Math.max(300, Math.min(400, W * 0.48)), marginLeft: 64, marginRight: 18, marginTop: 14,
      style: plotStyle(),
      x: { label: null },
      y: { grid: true, nice: true, label: null, tickFormat: sid === 'ICSA' ? (v: number) => (v >= 1e6 ? `${v / 1e6}M` : `${v / 1e3}k`) : undefined },
      marks: [
        Plot.rectX(rec, { x1: (r: Date) => r, x2: (r: Date) => new Date(r.getFullYear(), r.getMonth() + 1, 1), fill: C.muted, fillOpacity: 0.14 }),
        sid === 'T10Y3M' ? Plot.ruleY([0], { stroke: C.text2, strokeWidth: 1.5, strokeOpacity: 0.8 }) : null,
        ctxOn ? Plot.lineY(d, { x: 'date', y: 'value', stroke: C.history, strokeWidth: 1.25, strokeOpacity: 0.4 }) : null,
        Plot.lineY(full, { x: 'date', y: 'value', stroke: C.fitted, strokeWidth: native ? 1.5 : 2.2, curve: step ? 'step-after' : 'linear' }),
        !native && full.length < 260 ? Plot.dot(full, { x: 'date', y: 'value', r: 2.6, fill: C.fitted }) : null,
        Plot.dot(part, { x: 'date', y: 'value', r: 5, stroke: C.actual, strokeWidth: 2, fill: 'none' }),
        Plot.text(part, { x: 'date', y: 'value', text: () => 'partial period', dy: -12, textAnchor: 'end', fill: C.actual, fontSize: 12, fontWeight: 650, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
        sid === 'T10Y3M' ? Plot.text([0], { x: () => d[0].date, y: 0, text: () => 'inverted below this line', dy: 12, dx: 4, textAnchor: 'start', fill: C.muted, fontSize: 12, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }) : null,
        Plot.tip(agg.pts, Plot.pointerX({ x: 'date', y: 'value', title: (p: any) => `${lbl(p)}${p.partial ? ' (partial)' : ''}\n${fmtVal(p.value)}${!native ? `\n${p.n} ${SERIES[sid].native === 'D' ? 'trading days' : 'weeks'}` : ''}` })),
      ].filter(Boolean) as any,
    });
    chart.setAttribute('aria-label', `${SERIES[sid].label}, ${FREQS.find((f) => f.k === agg.f)?.label}, aggregated by ${how}. ${stats ? `${stats.n} periods.` : ''}`);
    chart.setAttribute('role', 'img');
    el.replaceChildren(chart);
  }

  $effect(() => { agg; rec; draw(); });
  const fmtStat = (v: number) => (sid === 'T10Y3M' ? `${v.toFixed(2)}` : Math.round(v).toLocaleString('en-US'));
</script>

<Explorable title="One daily series, many monthly series: the aggregation rule is a choice" caption={`Pick a <b>frequency</b> and an <b>aggregation rule</b>. The faint line is the original data; the cyan line is what you would hand to a model. Gray bands are NBER recessions. The last period is often incomplete: watch what the <b>sum</b> does to it. Data: FRED (${sid}, USREC), ${unit}.`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Series">
      {#each Object.entries(SERIES) as [k, s]}<button class:on={sid === k} aria-pressed={sid === k} onclick={() => (sid = k as Sid)}>{s.label}</button>{/each}
    </div>
    <div class="seg" role="group" aria-label="Frequency">
      {#each FREQS as f}<button class:on={(agg?.f ?? freq) === f.k} aria-pressed={(agg?.f ?? freq) === f.k} disabled={sid === 'ICSA' && f.k === 'D'} onclick={() => (freq = f.k)}>{f.label}</button>{/each}
    </div>
    <div class="seg" role="group" aria-label="Aggregation rule">
      {#each HOWS as h}<button class:on={how === h.k} aria-pressed={how === h.k} onclick={() => (how = h.k)}>{h.label}</button>{/each}
    </div>
  {/snippet}
  {#snippet aside()}
    {#if stats}
      <div class="board" aria-live="polite">
        <div class="unit">{unit}</div>
        <div class="row">
          <div class="stat"><span class="stat-v">{stats.n.toLocaleString('en-US')}</span><span class="stat-l">complete periods since 2006</span></div>
          {#if sid === 'T10Y3M'}
            <div class="stat"><span class="stat-v">{stats.inv.toLocaleString('en-US')}</span><span class="stat-l">of them inverted (below 0)</span></div>
          {:else}
            <div class="stat"><span class="stat-v">{fmtStat(stats.hi.value)}</span><span class="stat-l">peak, {monthLabel(stats.hi.date)}</span></div>
          {/if}
        </div>
        <p class="verdict">{@html verdict}</p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 300px; }
  .board { font-size: .86rem; line-height: 1.55; }
  .unit { font-size: .76rem; color: var(--muted); margin-bottom: .6rem; }
  .row { display: flex; gap: 1.4rem; margin-bottom: .8rem; }
  .verdict { color: var(--text-2); margin: 0; }
  .verdict :global(b) { color: var(--text); }
  :global(.exp .seg button:disabled) { opacity: .35; cursor: not-allowed; }
</style>
