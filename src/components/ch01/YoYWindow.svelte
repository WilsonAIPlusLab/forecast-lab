<script lang="ts">
  // YoY window: a year-over-year log change is exactly the sum of the last 12 monthly log changes.
  // Sliding the 12-month window shows (1) base effects: YoY moves when a big month drops OUT of the
  // window, not only when a new month comes in; (2) why YoY works on seasonal (NSA) data: every
  // window holds exactly one of each calendar month, so the seasonal swings cancel in the sum.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { loadPublished, monthLabel, mkey, signed } from './util';

  type Sid = 'CPIAUCSL' | 'RSXFSN';
  const SERIES: Record<Sid, { label: string; name: string; unit: string; jumps: [string, string][] }> = {
    CPIAUCSL: { label: 'Consumer prices (SA)', name: 'CPI', unit: 'CPI-U, index 1982–84 = 100, seasonally adjusted', jumps: [['2021-04', 'Apr 2021'], ['2022-07', 'Jul 2022']] },
    RSXFSN: { label: 'Retail sales (NSA)', name: 'Retail sales', unit: 'retail sales excl. food services, $ millions, not seasonally adjusted', jumps: [['2021-04', 'Apr 2021'], ['2025-12', 'Dec 2025']] },
  };
  const SHOW_FROM = new Date(2017, 0, 1);

  interface Row { date: Date; end: Date; d: number; yoyLog: number; yoyPct: number; est: boolean }
  let data: Partial<Record<Sid, Row[]>> = $state({});
  let sid: Sid = $state('CPIAUCSL');
  let sel = $state(0);              // index into rows of the selected month (end of the window)
  let elTop: HTMLDivElement;
  let elBot: HTMLDivElement;

  function build(values: { date: Date; value: number }[], missing: Set<string>): Row[] {
    return values.map((p, i) => {
      const prev = values[i - 1]?.value, prev12 = values[i - 12]?.value;
      const d = prev ? 100 * Math.log(p.value / prev) : NaN;           // monthly log change x 100
      const yoyLog = prev12 ? 100 * Math.log(p.value / prev12) : NaN;  // 12-month log change x 100 = sum of the last 12 d's
      const end = new Date(p.date.getFullYear(), p.date.getMonth() + 1, 1);
      // a monthly change is "estimated" if either of its two months was filled in by interpolation
      const est = missing.has(mkey(p.date)) || (i > 0 && missing.has(mkey(values[i - 1].date)));
      return { date: p.date, end, d, yoyLog, yoyPct: 100 * (Math.exp(yoyLog / 100) - 1), est };
    });
  }

  onMount(() => {
    (['CPIAUCSL', 'RSXFSN'] as Sid[]).forEach((id) => {
      // loadSeries fills the unpublished October 2025 CPI by interpolation (like fred()); loadPublished tells us which month that was
      Promise.all([loadSeries(id, { start: '2015-01-01' }), loadPublished(id)]).then(([s, g]) => {
        const missing = new Set(g.filter((p) => !Number.isFinite(p.value)).map((p) => mkey(p.date)));
        data = { ...data, [id]: build(s.data, missing) };
        if (id === sid) jump('2022-07');
      });
    });
    const off1 = watchLayout(elTop, draw);
    return () => off1();
  });

  const rows = $derived((data[sid] ?? []).filter((r) => r.date >= SHOW_FROM));
  const first = $derived(Math.max(0, rows.findIndex((r) => r.date >= new Date(2018, 0, 1))));
  function jump(k: string) {
    const r = (data[sid] ?? []).filter((x) => x.date >= SHOW_FROM);
    const i = k === 'last' ? r.length - 1 : r.findIndex((x) => mkey(x.date) === k);
    if (i >= 0) sel = i;
  }
  function pick(s: Sid) {
    const k = rows[sel] ? mkey(rows[sel].date) : 'last';   // keep the same month when switching series, if it exists
    sid = s;
    const r = (data[s] ?? []).filter((x) => x.date >= SHOW_FROM);
    const i = r.findIndex((x) => mkey(x.date) === k);
    sel = i >= 0 ? i : Math.max(0, r.length - 1);
  }

  const cur = $derived(rows[sel]);
  const enter = $derived(cur?.d ?? NaN);                 // this month's change: enters the window
  const leave = $derived(rows[sel - 12]?.d ?? NaN);      // same month last year: drops out of the window
  const prevYoY = $derived(rows[sel - 1]?.yoyLog ?? NaN);
  const anyEst = $derived(rows.slice(Math.max(0, sel - 11), sel + 1).some((r) => r.est));

  function story(): string {
    if (!cur || !Number.isFinite(leave)) return '';
    const move = enter - leave;
    if (sid === 'RSXFSN' && move > 4 && leave < 0) return `A huge <b>base effect</b>: the collapse a year ago (${signed(leave)}) dropped out of the window, so YoY growth soared even though this month itself (${signed(enter)}) was ordinary for the season.`;
    if (sid === 'RSXFSN' && move < -4 && leave > 0) return `A <b>base effect</b>: the rebound a year ago (${signed(leave)}) dropped out of the window, so YoY growth fell back even though this month (${signed(enter)}) was ordinary for the season.`;
    if (sid === 'RSXFSN') return `This month’s bar is ${signed(enter)} and the bar leaving is ${signed(leave)}: both are the same calendar month, so their seasonal swings mostly cancel. Every 12-month window holds exactly one of each month, which is why YoY works on unadjusted data.`;
    if (move < -0.15 && leave > 0 && enter > -0.1) return `This month’s change was only ${signed(enter, 2)}, yet YoY fell, mainly because a bigger rise a year ago (${signed(leave, 2)}) dropped out of the window. Economists call this a <b>base effect</b>.`;
    if (move > 0.15 && Math.abs(enter) < Math.abs(leave) + 0.6 && leave < 0) return `YoY jumped partly because a <i>fall</i> a year ago (${signed(leave, 2)}) dropped out of the window. That is a <b>base effect</b>: last year’s weak month flatters this year’s comparison.`;
    return `YoY moved by ${signed(move, 2)} points: the change coming in minus the change going out.`;
  }

  function draw() {
    if (!elTop || !elBot || !rows.length || !cur) return;
    const W = Math.max(280, elTop.clientWidth || 600);   // floor guards against a transient zero-width layout
    const x = { domain: [rows[0].date, rows[rows.length - 1].end], label: null };
    const role = (i: number) => (i === sel ? 'enter' : i === sel - 12 ? 'leave' : i > sel - 12 && i < sel ? 'in' : 'out');
    const bars = rows.map((r, i) => ({ ...r, role: role(i) }));
    const fill = (r: { role: string }) => (r.role === 'enter' ? C.actual : r.role === 'leave' ? C.forecast : r.role === 'in' ? C.fitted : C.muted);
    const ext = Math.max(...rows.map((r) => Math.abs(r.d)).filter(Number.isFinite));
    const top = Plot.plot({
      width: W, height: Math.max(190, Math.min(240, W * 0.3)), marginLeft: 46, marginRight: 12, marginTop: 14, marginBottom: 22,
      style: plotStyle(), x: { ...x, type: 'time', axis: null },
      y: { grid: true, label: 'monthly log change × 100', domain: [-ext * 1.05, ext * 1.05], ticks: 5 },
      marks: [
        Plot.rectY(bars, { x1: 'date', x2: 'end', y: 'd', fill, fillOpacity: (r: any) => (r.role === 'out' ? 0.35 : 0.95), insetLeft: 0.5, insetRight: 0.5 }),
        Plot.rectY(bars.filter((r) => r.est), { x1: 'date', x2: 'end', y: 'd', fill: 'none', stroke: C.text2, strokeDasharray: '2 2' }),
        Plot.ruleY([0], { stroke: C.text2, strokeWidth: 1 }),
        Plot.text([bars[sel]], { x: 'date', y: 'd', text: () => 'in', dy: enter >= 0 ? -10 : 12, dx: 3, fill: C.text, fontSize: 12, fontWeight: 700, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
        ...(bars[sel - 12] ? [Plot.text([bars[sel - 12]], { x: 'date', y: 'd', text: () => 'out', dy: leave >= 0 ? -10 : 12, dx: 3, fill: C.text, fontSize: 12, fontWeight: 700, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' })] : []),
        Plot.tip(bars, Plot.pointerX({ x: 'date', y: 'd', title: (r: Row) => `${monthLabel(r.date)}\nchange from previous month: ${signed(r.d, 2)} log points (≈ %)${r.est ? '\n(uses the interpolated October 2025)' : ''}` })),
      ],
    });
    top.setAttribute('role', 'img');
    top.setAttribute('aria-label', `${SERIES[sid].name}: monthly log changes since 2017. The 12 months ending ${monthLabel(cur.date)} are highlighted; they add up to ${cur.yoyLog.toFixed(2)}.`);
    elTop.replaceChildren(top);

    const line = rows.filter((r) => Number.isFinite(r.yoyPct));
    const bot = Plot.plot({
      width: W, height: Math.max(160, Math.min(200, W * 0.25)), marginLeft: 46, marginRight: 12, marginTop: 10,
      style: plotStyle(), x: { ...x, type: 'time' },
      y: { grid: true, label: 'YoY % change', ticks: 4, nice: true },
      marks: [
        Plot.ruleY([0], { stroke: C.text2, strokeWidth: 1 }),
        Plot.lineY(line, { x: 'date', y: 'yoyPct', stroke: C.history, strokeWidth: 2.2 }),
        Plot.ruleX([cur.date], { stroke: C.actual, strokeWidth: 1.5, strokeOpacity: 0.7 }),
        Plot.dot([cur], { x: 'date', y: 'yoyPct', r: 5.5, fill: C.actual, stroke: C.surface, strokeWidth: 2 }),
        Plot.tip(line, Plot.pointerX({ x: 'date', y: 'yoyPct', title: (r: Row) => `${monthLabel(r.date)}\nYoY: ${signed(r.yoyPct)}%` })),
      ],
    });
    bot.setAttribute('role', 'img');
    bot.setAttribute('aria-label', `${SERIES[sid].name}: year-over-year percent change. ${monthLabel(cur.date)}: ${signed(cur.yoyPct)}%.`);
    elBot.replaceChildren(bot);
  }

  $effect(() => { rows; sel; draw(); });
</script>

<Explorable title="Year-over-year growth is the last 12 monthly changes added up" caption={`Top: each bar is one month’s change (log change × 100, close to a % change). Bottom: the year-over-year change. Drag the <b>month</b> slider: the 12 highlighted bars always add up to the YoY number below. The gold bar comes <b>in</b>, the violet bar drops <b>out</b>. Dashed outlines mark months that use the interpolated October 2025 CPI, which BLS never published. Data: FRED (${sid}), ${SERIES[sid].unit}.`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Series">
      {#each Object.entries(SERIES) as [k, s]}<button class:on={sid === k} aria-pressed={sid === k} onclick={() => pick(k as Sid)}>{s.label}</button>{/each}
    </div>
    <label class="sl">Month
      <input type="range" min={first} max={Math.max(first, rows.length - 1)} step="1" bind:value={sel} aria-label="Last month of the 12-month window" aria-valuetext={cur ? monthLabel(cur.date) : ''} />
      <b>{cur ? monthLabel(cur.date) : '…'}</b>
    </label>
    <div class="seg" role="group" aria-label="Jump to a month">
      {#each SERIES[sid].jumps as [k, l]}<button onclick={() => jump(k)}>{l}</button>{/each}
      <button onclick={() => jump('last')}>Latest</button>
    </div>
  {/snippet}
  {#snippet aside()}
    <div class="board" aria-live="polite">
      {#if cur && Number.isFinite(cur.yoyLog)}
        <div class="stat"><span class="stat-v yy">{signed(cur.yoyPct)}%</span><span class="stat-l">YoY % change, {monthLabel(cur.date)}</span></div>
        <p class="sum">Sum of the 12 highlighted bars: <b>{cur.yoyLog.toFixed(2)}</b> log points. As a percent change: 100 × (e<sup>{(cur.yoyLog / 100).toFixed(4)}</sup> − 1) = <b>{signed(cur.yoyPct, 2)}%</b>.</p>
        <table class="io">
          <tbody>
            <tr><td><span class="sw in"></span>In: {monthLabel(cur.date)}</td><td>{signed(enter, 2)}</td></tr>
            <tr><td><span class="sw out"></span>Out: {rows[sel - 12] ? monthLabel(rows[sel - 12].date) : ''}</td><td>{signed(leave, 2)}</td></tr>
            <tr class="tot"><td>Change in YoY (log points)</td><td>{signed(cur.yoyLog - prevYoY, 2)}</td></tr>
          </tbody>
        </table>
        <p class="what">{@html story()}</p>
        {#if anyEst}<p class="hint">This window includes the interpolated October 2025, so treat the number as an estimate.</p>{/if}
      {/if}
    </div>
  {/snippet}
  <div bind:this={elTop} class="chart top"></div>
  <div bind:this={elBot} class="chart bot"></div>
</Explorable>

<style>
  .chart.top { min-height: 190px; }
  .chart.bot { min-height: 160px; }
  .board { font-size: .86rem; line-height: 1.55; display: grid; gap: .65rem; }
  .yy { color: var(--c-history); }
  .sum, .what { margin: 0; color: var(--text-2); }
  .hint { margin: 0; color: var(--muted); font-size: .78rem; }
  .io { width: 100%; margin: 0 !important; font-size: .82rem; border-collapse: collapse; }
  .io td { padding: .2rem .1rem; border-bottom: 1px solid var(--border); font-variant-numeric: tabular-nums; }
  .io td:last-child { text-align: right; font-family: var(--font-mono); }
  .io .tot td { font-weight: 650; color: var(--text); border-bottom: 0; }
  .sw { display: inline-block; width: .7rem; height: .7rem; border-radius: 2px; margin-right: .4rem; vertical-align: -1px; }
  .sw.in { background: var(--c-actual); }
  .sw.out { background: var(--c-forecast); }
</style>
