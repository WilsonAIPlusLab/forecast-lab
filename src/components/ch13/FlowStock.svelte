<script lang="ts">
  // Mixed frequencies: turn a weekly or daily series into one number per month, three ways (average, sum, end of period),
  // and see which choices make sense for a flow, a stock and a price.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { ymKey } from './lib';

  type Kind = 'flow' | 'stock' | 'price';
  type Method = 'avg' | 'sum' | 'eop';
  const SERIES: { id: string; short: string; label: string; kind: Kind; unit: string; scale: number; step: number; obs: string }[] = [
    { id: 'ICSA', short: 'Initial claims', label: 'Initial jobless claims: new filings each week', kind: 'flow', unit: 'thousand claims', scale: 1e-3, step: 7, obs: 'week' },
    { id: 'CCSA', short: 'Continuing claims', label: 'Continuing claims: people on benefits that week', kind: 'stock', unit: 'thousand people', scale: 1e-3, step: 7, obs: 'week' },
    { id: 'GASREGW', short: 'Gasoline price', label: 'Regular gasoline, U.S. average price (weekly, Mondays)', kind: 'price', unit: '$ per gallon', scale: 1, step: 7, obs: 'week' },
    { id: 'DCOILWTICO', short: 'Crude oil (daily)', label: 'WTI crude oil price (daily, trading days)', kind: 'price', unit: '$ per barrel', scale: 1, step: 1, obs: 'trading day' },
  ];
  const METHODS: { k: Method; label: string }[] = [
    { k: 'avg', label: 'Average' },
    { k: 'sum', label: 'Sum' },
    { k: 'eop', label: 'End of month' },
  ];
  // Plain-words verdict for each kind × method.
  const VERDICT: Record<Kind, Record<Method, { ok: 'yes' | 'care' | 'no'; text: string }>> = {
    flow: {
      avg: { ok: 'yes', text: 'A weekly rate: “a typical week in this month”. It does not depend on how many weeks the month has. This is what FRED and the bridge lab use.' },
      sum: { ok: 'care', text: 'A monthly total is meaningful for a flow, but months with five weeks look about 20% bigger than months with four. Compare totals only year over year, or divide by the number of weeks.' },
      eop: { ok: 'care', text: 'Keeps only the last week and throws the rest of the month away. Noisier, and it misses layoffs early in the month.' },
    },
    stock: {
      avg: { ok: 'yes', text: 'The average number of people on benefits during the month. Smooth and defensible.' },
      sum: { ok: 'no', text: 'Meaningless. The same people are counted every week they stay on benefits, so the “total” just grows with the number of weeks.' },
      eop: { ok: 'yes', text: 'The count at month end, like an inventory taken on the last day. The natural choice for a stock.' },
    },
    price: {
      avg: { ok: 'yes', text: 'The average price paid during the month. Use it when the target is spending or a monthly price index.' },
      sum: { ok: 'no', text: 'Meaningless. Adding prices gives “dollars per gallon × weeks”, which only measures how many prints the month had.' },
      eop: { ok: 'yes', text: 'The latest price when the month closes: what a trader knows on the last day. Use it for “where are we now”.' },
    },
  };
  const KIND_LABEL: Record<Kind, string> = { flow: 'a flow', stock: 'a stock', price: 'a price' };

  let sIdx = $state(0);
  let method: Method = $state('avg');
  let year = $state(2026);
  let raw: Record<string, { date: Date; v: number }[]> = $state({});
  let el: HTMLDivElement, elChg: HTMLDivElement;
  const ser = $derived(SERIES[sIdx]);

  onMount(() => {
    Promise.all(SERIES.map((s) => loadSeries(s.id))).then((all) => {
      const o: Record<string, { date: Date; v: number }[]> = {};
      all.forEach((x, j) => (o[SERIES[j].id] = x.data.map((p) => ({ date: p.date, v: p.value * SERIES[j].scale }))));
      raw = o;
    });
    return watchLayout(el, draw);
  });

  // Monthly aggregates of the chosen series (complete months only).
  const monthly = $derived.by(() => {
    const d = raw[ser.id];
    if (!d) return null;
    const g = new Map<string, { date: Date; v: number }[]>();
    for (const p of d) { const k = ymKey(p.date); (g.get(k) || g.set(k, []).get(k)!).push(p); }
    // drop the newest month if the next observation would still fall inside it (an incomplete month)
    const last = d[d.length - 1].date;
    const next = new Date(+last + ser.step * 864e5);
    if (ymKey(next) === ymKey(last)) g.delete(ymKey(last));
    const rows = [...g].map(([k, pts]) => {
      const [y, m] = k.split('-').map(Number);
      const val = { avg: pts.reduce((s, p) => s + p.v, 0) / pts.length, sum: pts.reduce((s, p) => s + p.v, 0), eop: pts[pts.length - 1].v };
      return { k, y, a: new Date(y, m - 1, 1), b: new Date(y, m, 1), n: pts.length, pts, val };
    }).sort((p, q) => (p.k < q.k ? -1 : 1));
    // month-over-month % change for each method (100 x log change)
    return rows.map((r, i) => ({ ...r, chg: i ? Object.fromEntries((['avg', 'sum', 'eop'] as Method[]).map((mm) => [mm, 100 * Math.log(r.val[mm] / rows[i - 1].val[mm])])) as Record<Method, number> : null, nPrev: i ? rows[i - 1].n : null }));
  });
  const years = $derived.by(() => {
    if (!monthly) return [2000, 2026];
    return [Math.max(2000, monthly[0].y + 1), monthly[monthly.length - 1].y];
  });
  $effect(() => { if (monthly && year > years[1]) year = years[1]; });

  // Calm-period statistics (2010-2019): how jumpy is each version, and how big is the "extra week" effect?
  const stats = $derived.by(() => {
    if (!monthly) return null;
    const rows = monthly.filter((r) => r.y >= 2010 && r.y <= 2019 && r.chg);
    const sd = (xs: number[]) => { const m = xs.reduce((s, v) => s + v, 0) / xs.length; return Math.sqrt(xs.reduce((s, v) => s + (v - m) ** 2, 0) / (xs.length - 1)); };
    const up = rows.filter((r) => r.n > (r.nPrev ?? 0));
    const jump = up.length ? up.reduce((s, r) => s + r.chg![method], 0) / up.length : NaN;
    return { sd: sd(rows.map((r) => r.chg![method])), sdAvg: sd(rows.map((r) => r.chg!.avg)), jump, nUp: up.length };
  });
  const view = $derived(monthly ? monthly.filter((r) => r.y === year) : []);
  const verdict = $derived(VERDICT[ser.kind][method]);
  const f1 = (v: number) => (Math.abs(v) >= 100 ? Math.round(v).toLocaleString('en-US') : v.toFixed(2));

  function draw() {
    if (!el || !elChg || !view.length) return;
    const W = el.clientWidth;
    if (W < 200) return; // not laid out yet; watchLayout redraws once it has a real width
    const pts = view.flatMap((r) => r.pts.map((p, i) => ({ ...p, used: method === 'eop' ? i === r.pts.length - 1 : true })));
    const segs = view.map((r) => ({ a: r.a, b: r.b, v: r.val[method], n: r.n, k: r.k }));
    const showPts = method !== 'sum';
    const dot = ser.step === 1 ? 2 : 3.5;
    const main = Plot.plot({
      width: W, height: 280, marginLeft: 56, marginRight: 12, marginTop: 22, style: plotStyle(),
      x: { type: 'time', label: null, domain: [view[0].a, view[view.length - 1].b] },
      y: { grid: true, label: `↑ ${method === 'sum' ? 'monthly total, ' : ''}${ser.unit}`, nice: true, zero: method === 'sum' },
      marks: [
        // light month boundaries
        Plot.ruleX(view.map((r) => r.a), { stroke: C.border, strokeOpacity: 0.7 }),
        ...(showPts ? [
          Plot.line(pts, { x: 'date', y: 'v', stroke: C.history, strokeWidth: 1.25, strokeOpacity: 0.4 }),
          Plot.dot(pts, { x: 'date', y: 'v', r: dot, fill: (p: any) => (p.used ? C.history : 'none'), stroke: C.history, strokeOpacity: (p: any) => (p.used ? 0.9 : 0.45), fillOpacity: 0.55 }),
        ] : []),
        // the monthly number: one bar-top segment per month
        Plot.ruleY(segs, { x1: (s: any) => new Date(+s.a + 2 * 864e5), x2: (s: any) => new Date(+s.b - 2 * 864e5), y: 'v', stroke: C.forecast, strokeWidth: 3.5 }),
        ...(method === 'sum' ? [Plot.text(segs.filter((s) => s.n >= 5 || ser.step === 1), { x: (s: any) => new Date((+s.a + +s.b) / 2), y: 'v', text: (s: any) => `${s.n} ${ser.step === 1 ? 'days' : 'wks'}`, dy: -10, fill: C.text2, fontSize: 12 })] : []),
        Plot.tip(segs, Plot.pointerX({ x: (s: any) => new Date((+s.a + +s.b) / 2), y: 'v', title: (s: any) => `${s.k}: ${f1(s.v)} ${ser.unit}\n${METHODS.find((m) => m.k === method)!.label} of ${s.n} ${ser.obs}s` })),
      ],
    });
    main.setAttribute('aria-label', `${ser.short} in ${year}: ${ser.obs}ly values as dots and the monthly ${METHODS.find((m) => m.k === method)!.label.toLowerCase()} as a violet bar for each month.`);
    el.replaceChildren(main);

    const chg = view.filter((r) => r.chg).map((r) => ({ a: r.a, b: r.b, c: r.chg![method], more: r.n > (r.nPrev ?? 0), n: r.n }));
    const ch2 = Plot.plot({
      width: W, height: 150, marginLeft: 56, marginRight: 12, marginTop: 14, style: plotStyle(),
      x: { type: 'time', label: null, domain: [view[0].a, view[view.length - 1].b] },
      y: { grid: true, label: '↑ change vs last month (%)', nice: true },
      marks: [
        Plot.rectY(chg, { x1: (r: any) => new Date(+r.a + 3 * 864e5), x2: (r: any) => new Date(+r.b - 3 * 864e5), y: 'c', fill: (r: any) => (r.more ? C.s[1] : C.history), fillOpacity: (r: any) => (r.more ? 0.9 : 0.55) }),
        Plot.ruleY([0], { stroke: C.borderStrong }),
        Plot.text(chg.filter((r) => r.more && ser.step === 7), { x: (r: any) => new Date((+r.a + +r.b) / 2), y: (r: any) => Math.max(r.c, 0), text: () => '+1 wk', dy: -8, fill: C.text2, fontSize: 12 }),
        Plot.tip(chg, Plot.pointerX({ x: (r: any) => new Date((+r.a + +r.b) / 2), y: 'c', title: (r: any) => `${r.c >= 0 ? '+' : ''}${r.c.toFixed(1)}% vs previous month\n${r.n} ${ser.obs}s this month${r.more ? ' (one more than last month)' : ''}` })),
      ],
    });
    ch2.setAttribute('aria-label', `Month-over-month percent change of the monthly ${METHODS.find((m) => m.k === method)!.label.toLowerCase()}. Months with an extra ${ser.obs} are highlighted.`);
    elChg.replaceChildren(ch2);
  }
  $effect(() => { view; method; sIdx; draw(); });
</script>

<Explorable title="The five-week trap: one weekly series, three monthly numbers" caption={`Pick a series and a way to turn it into one number per month. Dots are the raw weekly or daily prints. Each violet bar is the monthly number. With <b>End of month</b>, only the filled dot counts. The lower panel shows the month-to-month change; rose bars mark months with one more week (or trading day) than the month before. Seasonally adjusted except prices. Data: FRED (ICSA, CCSA, GASREGW, DCOILWTICO).`}>
  {#snippet controls()}
    <label class="pick">Series
      <select bind:value={sIdx} aria-label="Series">
        {#each SERIES as s, i}<option value={i}>{s.short}</option>{/each}
      </select>
    </label>
    <div class="seg" role="group" aria-label="Monthly summary">
      {#each METHODS as m}<button class:on={method === m.k} aria-pressed={method === m.k} onclick={() => (method = m.k)}>{m.label}</button>{/each}
    </div>
    <label class="sl">Year <input type="range" min={years[0]} max={years[1]} step="1" bind:value={year} aria-label="Year shown" /> <b>{year}</b></label>
  {/snippet}
  {#snippet aside()}
    <div class="side" aria-live="polite">
      <div class="eyebrow">{ser.short} is {KIND_LABEL[ser.kind]}</div>
      <p class="lbl">{ser.label}.</p>
      <div class="verdict {verdict.ok}">
        <span class="badge">{verdict.ok === 'yes' ? '✓ Sensible' : verdict.ok === 'care' ? '△ Use with care' : '✗ Meaningless'}</span>
        <p>{verdict.text}</p>
      </div>
      {#if stats && Number.isFinite(stats.sd)}
        <div class="eyebrow" style="margin-top:.7rem">Calm years, 2010–2019</div>
        <div class="kp"><span class="v">{stats.sd.toFixed(1)}%</span><span class="l">typical month-to-month change (std. dev.) with this summary{method !== 'avg' ? `; ${stats.sdAvg.toFixed(1)}% with the average` : ''}</span></div>
        {#if Number.isFinite(stats.jump)}
          <div class="kp"><span class="v">{stats.jump >= 0 ? '+' : ''}{stats.jump.toFixed(1)}%</span><span class="l">average change in the {stats.nUp} months that had one more {ser.obs} than the month before</span></div>
        {/if}
      {/if}
    </div>
  {/snippet}
  <div bind:this={el} class="chart"></div>
  <div bind:this={elChg} class="chart2"></div>
  {#if !monthly}<p class="load">Loading…</p>{/if}
</Explorable>

<style>
  .chart { min-height: 280px; }
  .chart2 { min-height: 150px; margin-top: .4rem; }
  .pick { display: inline-flex; gap: .5rem; align-items: center; }
  .pick select { font: inherit; padding: .25rem .4rem; border-radius: 7px; border: 1px solid var(--border); background: var(--bg); color: var(--text); }
  .side { font-size: .82rem; }
  .lbl { color: var(--text-2); margin: .2rem 0 .5rem; }
  .verdict { border: 1px solid var(--border); border-radius: 8px; padding: .5rem .6rem; background: var(--bg-2); }
  .verdict p { margin: .3rem 0 0; color: var(--text-2); }
  .badge { font-weight: 700; }
  .verdict.yes .badge { color: var(--good); }
  .verdict.care .badge { color: var(--c-actual); }
  .verdict.no .badge { color: var(--danger); }
  .kp { display: flex; flex-direction: column; margin: .45rem 0; }
  .kp .v { font: 700 1.35rem/1.1 var(--font-ui); color: var(--text); font-variant-numeric: tabular-nums; }
  .kp .l { color: var(--muted); font-size: .76rem; }
  .load { color: var(--muted); }
</style>
