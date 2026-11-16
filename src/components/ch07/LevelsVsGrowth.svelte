<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, type Pt } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { logDiff, key, corr, ymLabel } from './lib';
  import './viz';

  // Levels vs growth rates: the same pair of series can look perfectly related in levels
  // (because both trend) and only loosely related once each is turned into a growth rate.
  type Tf = 'level' | 'mom' | 'yoy';
  type Partner = 'claims' | 'cpi';
  type Period = 'all' | '2010s';
  const TF: Record<Tf, { label: string; long: string }> = {
    level: { label: 'Levels', long: 'levels' },
    yoy: { label: '12-month % change', long: '% change from a year earlier' },
    mom: { label: 'Monthly % change', long: '% change from the previous month' },
  };
  const PARTNER: Record<Partner, { label: string; id: string; to?: 'month'; unitLevel: string; scale: number; short: string }> = {
    claims: { label: 'Initial claims', id: 'ICSA', to: 'month', unitLevel: 'thousands of new claims a week', scale: 1000, short: 'claims' },
    cpi: { label: 'Consumer prices (CPI)', id: 'CPIAUCSL', unitLevel: 'index, 1982–84 = 100', scale: 1, short: 'CPI' },
  };
  const PERIOD: Record<Period, { label: string; from: string; to: string }> = {
    all: { label: '1990–2019', from: '1990-01', to: '2019-12' },
    '2010s': { label: '2010–2019', from: '2010-01', to: '2019-12' },
  };

  let tf: Tf = $state('level');
  let partner: Partner = $state('claims');
  let period: Period = $state('2010s');
  let raw: Record<string, Pt[]> = $state({});
  let el: HTMLDivElement;

  onMount(() => {
    (async () => {
      const [p, c, i] = await Promise.all([loadSeries('PAYEMS'), loadSeries('ICSA', { to: 'month' }), loadSeries('CPIAUCSL')]);
      raw = { jobs: p.data, claims: c.data, cpi: i.data };
    })();
    return watchLayout(el, draw);
  });

  const tfm = (d: Pt[], t: Tf) => (t === 'level' ? d : logDiff(d, t === 'mom' ? 1 : 12));

  // Align the jobs measure and the partner measure on common months inside the chosen period.
  function pairs(t: Tf, pa: Partner, pe: Period) {
    if (!raw.jobs) return [];
    const { from, to } = PERIOD[pe];
    const X = new Map(tfm(raw[pa], t).map((p) => [key(p.date), p.value]));
    return tfm(raw.jobs, t).filter((p) => key(p.date) >= from && key(p.date) <= to && X.has(key(p.date)))
      .map((p) => ({ date: p.date, y: p.value, x: X.get(key(p.date))! }));
  }
  const rows = $derived(pairs(tf, partner, period));
  const r = $derived(rows.length > 2 ? corr(rows.map((d) => d.x), rows.map((d) => d.y)) : NaN);
  // r for all three transformations (current partner and period), for the comparison table.
  const table = $derived((Object.keys(TF) as Tf[]).map((t) => { const d = pairs(t, partner, period); return { t, r: d.length > 2 ? corr(d.map((q) => q.x), d.map((q) => q.y)) : NaN }; }));

  function draw() {
    if (!el || !rows.length) return;
    const W = el.clientWidth;
    const lvl = tf === 'level';
    const sx = lvl ? PARTNER[partner].scale : 1, sy = lvl ? 1000 : 1;   // levels: claims in thousands, jobs in millions
    const d = rows.map((q) => ({ ...q, xs: q.x / sx, ys: q.y / sy, yr: q.date.getFullYear() + q.date.getMonth() / 12 }));
    const first = d[0], last = d[d.length - 1];
    const xl = lvl ? `${PARTNER[partner].label} (${PARTNER[partner].unitLevel})` : `${PARTNER[partner].label}, ${TF[tf].long}`;
    const yl = lvl ? 'Payroll jobs (millions)' : `Payroll jobs, ${TF[tf].long}`;
    const accent = getComputedStyle(el).getPropertyValue('--ch').trim() || C.s[3];
    const lab = { fill: C.text, fontSize: 12, fontWeight: 650, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' } as any;
    const chart = Plot.plot({
      width: W, height: Math.max(290, Math.min(400, W * 0.62)), marginLeft: 50, marginRight: 18, marginTop: 28, marginBottom: 42, style: plotStyle(),
      x: { label: xl, labelAnchor: 'center', labelArrow: 'none' as any, grid: true, ticks: Math.max(3, Math.floor(W / 110)) },
      y: { label: yl, labelAnchor: 'top' as any, grid: true },
      color: { type: 'linear', domain: [first.yr, last.yr], range: [C.s[0], accent], interpolate: 'hcl' },
      marks: [
        lvl ? null : Plot.ruleX([0], { stroke: C.borderStrong }),
        lvl ? null : Plot.ruleY([0], { stroke: C.borderStrong }),
        Plot.line(d, { x: 'xs', y: 'ys', stroke: C.muted, strokeOpacity: 0.4, strokeWidth: 1.25 }),
        Plot.dot(d, { x: 'xs', y: 'ys', fill: 'yr', r: 2.6, fillOpacity: 0.85 }),
        Plot.dot([first, last], { x: 'xs', y: 'ys', stroke: C.text, r: 5, fill: 'none', strokeWidth: 1.5 }),
        Plot.text([first], { x: 'xs', y: 'ys', text: () => ymLabel(first.date), dy: -12, ...lab }),
        Plot.text([last], { x: 'xs', y: 'ys', text: () => ymLabel(last.date), dy: 14, ...lab }),
        Plot.tip(d, Plot.pointer({ x: 'xs', y: 'ys', title: (q: any) => `${ymLabel(q.date)}\n${PARTNER[partner].short}: ${q.xs.toFixed(lvl ? 1 : 2)}${lvl ? '' : '%'}\njobs: ${q.ys.toFixed(lvl ? 2 : 2)}${lvl ? ' million' : '%'}` })),
      ].filter(Boolean) as any,
    });
    chart.setAttribute('aria-label', `Scatter of ${xl} against ${yl}, ${PERIOD[period].label}; correlation ${r.toFixed(2)}`);
    el.replaceChildren(chart);
  }
  $effect(() => { rows; draw(); });

  const sgn = (v: number) => (Number.isFinite(v) ? (v < 0 ? '−' : '') + Math.abs(v).toFixed(2) : '—');
  const cpiLevel = $derived.by(() => { const d = pairs('level', 'cpi', period); return d.length > 2 ? corr(d.map((q) => q.x), d.map((q) => q.y)) : NaN; });
  const verdict = $derived.by(() => {
    if (!Number.isFinite(r)) return '';
    if (tf === 'level') return partner === 'cpi'
      ? 'Prices have nothing to do with how many people are on payrolls, yet the fit looks almost perfect. Both series simply rose over time: the dots trace the calendar, not a relationship.'
      : `Claims drifted down while jobs drifted up, so the levels move in opposite directions. But consumer prices, which have nothing to do with hiring, score r = ${sgn(cpiLevel)} with jobs in levels. In levels you cannot tell a real link from a shared trend.`;
    if (partner === 'cpi') return 'Once each series is a growth rate, the shared trend is gone, and so is most of the "relationship". This is the honest number.';
    return r > 0
      ? 'Positive, the "wrong" sign! In the calm 2010s, same-month changes miss the timing: claims move months before jobs do. Growth rates make the question meaningful; the cross-correlation adds the timing.'
      : 'Negative, as expected: months in which claims grow faster tend to be months in which jobs grow slower. This is a relationship between changes, not between two trends.';
  });
</script>

<Explorable title="Two trending series always look related in levels" caption={`Each dot is one month; colour runs from the first month (blue) to the last (orange), and the grey line joins them in time order. In <b>levels</b> the dots march along a line because both series trend, so the correlation mostly measures the passage of time. Turn both into <b>growth rates</b> and the trend drops out; what is left is how the <i>changes</i> move together. Claims are the monthly average of weekly initial claims. Data: FRED (PAYEMS, ICSA, CPIAUCSL), seasonally adjusted.`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Compare payroll jobs with">
      {#each Object.entries(PARTNER) as [kk, d]}<button class:on={partner === kk} aria-pressed={partner === kk} onclick={() => (partner = kk as Partner)}>{d.label}</button>{/each}
    </div>
    <div class="seg" role="group" aria-label="Transformation applied to both series">
      {#each Object.entries(TF) as [kk, d]}<button class:on={tf === kk} aria-pressed={tf === kk} onclick={() => (tf = kk as Tf)}>{d.label}</button>{/each}
    </div>
    <div class="seg" role="group" aria-label="Sample period">
      {#each Object.entries(PERIOD) as [kk, d]}<button class:on={period === kk} aria-pressed={period === kk} onclick={() => (period = kk as Period)}>{d.label}</button>{/each}
    </div>
  {/snippet}
  {#snippet aside()}
    <div class="ro" aria-live="polite">
      <div class="stat"><span class="stat-v">r = {sgn(r)}</span><span class="stat-l">correlation of {PARTNER[partner].short} with payroll jobs, {TF[tf].long}, {PERIOD[period].label}</span></div>
      <table class="mini" aria-label="Correlation under each transformation">
        <tbody>
          {#each table as row}<tr class:on={row.t === tf}><td>{TF[row.t].label}</td><td class="num">{sgn(row.r)}</td></tr>{/each}
        </tbody>
      </table>
      <p class="v">{verdict}</p>
    </div>
  {/snippet}
  <div bind:this={el} class="chart" role="img" aria-label="Scatter plot of payroll jobs against the chosen series"></div>
</Explorable>

<style>
  .chart { min-height: 290px; }
  .ro { display: flex; flex-direction: column; gap: .7rem; font-size: .84rem; }
  .v { margin: 0; color: var(--text-2); }
  .mini { margin: 0 !important; font-size: .8rem !important; width: 100%; border-collapse: collapse; }
  .mini td { padding: .22rem .4rem; border-bottom: 1px solid var(--border); }
  .mini tr.on td { font-weight: 700; color: var(--text); background: var(--bg-2); }
  .mini .num { text-align: right; font-family: var(--font-mono); }
</style>
