<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { ols, ymKey, monthName, dayFmt, reduceMotion } from './lib';
  import './viz';

  // Target months students can pick. "live" = the newest month, whose jobs report is still in the future.
  const PRESETS = [
    { key: '2026-11', label: 'Nov 2026 (live)' },
    { key: '2026-10', label: 'Oct 2026 (calm)' },
    { key: '2008-09', label: 'Sep 2008 (Lehman)' },
    { key: '2020-03', label: 'Mar 2020 (COVID)' },
  ];
  const DAY = 864e5;
  /** Calendar-day arithmetic (safe across daylight-saving changes); fractional days add hours. */
  const addDays = (d: Date, n: number) => { const r = new Date(d); const whole = Math.trunc(n); r.setDate(r.getDate() + whole); return new Date(+r + (n - whole) * DAY); };
  const noon = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate(), 12);

  /** BLS usually publishes the jobs report on the third Friday after the week that contains the 12th. */
  function jobsFriday(y: number, m: number) {
    const d12 = new Date(y, m, 12);
    const sat = addDays(d12, 6 - d12.getDay());
    return addDays(sat, 20);
  }
  /** DOL publishes claims on the Thursday after the week ends (Wednesday in Thanksgiving week). */
  function claimsRelease(weekEnd: Date) {
    const thu = addDays(weekEnd, 5);
    const isThanksgiving = thu.getMonth() === 10 && thu.getDate() >= 22 && thu.getDate() <= 28;
    return isThanksgiving ? addDays(thu, -1) : thu;
  }

  let target = $state('2026-11');
  let day = $state(0);
  let playing = $state(false);
  let timer: any;
  let ready = $state(false);
  let elCal: HTMLDivElement, elNow: HTMLDivElement;

  // data
  let weeks = new Map<string, { date: Date; v: number }[]>();
  let fullAvg = new Map<string, number>();
  let dp = new Map<string, number>();
  let lastWeek: Date = new Date();

  onMount(async () => {
    const [ic, pay] = await Promise.all([loadSeries('ICSA'), loadSeries('PAYEMS')]);
    for (const p of ic.data) { const k = ymKey(p.date); (weeks.get(k) || weeks.set(k, []).get(k)!).push({ date: p.date, v: p.value / 1000 }); }
    for (const [k, w] of weeks) fullAvg.set(k, w.reduce((s, x) => s + x.v, 0) / w.length);
    for (let i = 1; i < pay.data.length; i++) dp.set(ymKey(pay.data[i].date), pay.data[i].value - pay.data[i - 1].value);
    lastWeek = ic.data[ic.data.length - 1].date;
    ready = true;
  });

  const prevKey = (k: string) => { const [y, m] = k.split('-').map(Number); return ymKey(new Date(y, m - 2, 1)); };

  // Everything that depends on the target month: timeline, events, one bridge regression per number of weeks known.
  const model = $derived.by(() => {
    if (!ready) return null;
    const [y, m] = target.split('-').map(Number);
    const start = noon(jobsFriday(y, m - 2)); // last month's jobs report: the clock starts here
    const end = noon(jobsFriday(y, m - 1));   // this month's jobs report
    const nDays = Math.round((+end - +start) / DAY); // DST shifts are under an hour, so rounding is safe
    const known = weeks.get(target) ?? [];
    // all Saturdays in the target month (some may be in the future for the live month)
    const sats: Date[] = [];
    for (let d = new Date(y, m - 1, 1); d.getMonth() === m - 1; d = addDays(d, 1)) if (d.getDay() === 6) sats.push(new Date(d));
    const wk = sats.map((s, i) => { const kn = known.find((w) => Math.abs(+w.date - +s) < 2 * DAY); return { end: s, rel: noon(claimsRelease(s)), v: kn?.v ?? null, i }; });
    const K = wk.length;
    const prevFull = fullAvg.get(prevKey(target))!;
    const lag = dp.get(prevKey(target))!;
    // training months: 1990 onward, before the target, skipping 2020-2021 (COVID swings swamp least squares)
    const train = [...dp.keys()].filter((k) => k >= '1990-01' && k < target && !k.startsWith('2020') && !k.startsWith('2021') && dp.has(prevKey(k)) && fullAvg.has(prevKey(k)) && weeks.has(k));
    const fits = Array.from({ length: K + 1 }, (_, k) => {
      if (k === 0) return ols(train.map((t) => [dp.get(prevKey(t))!]), train.map((t) => dp.get(t)!));
      const X = train.map((t) => { const w = weeks.get(t)!; const part = w.slice(0, Math.min(k, w.length)); return [dp.get(prevKey(t))!, part.reduce((s, x) => s + x.v, 0) / part.length - fullAvg.get(prevKey(t))!]; });
      return ols(X, train.map((t) => dp.get(t)!));
    });
    const nowAt = (k: number) => {
      if (k === 0) return { f: fits[0].predict([lag]), s: fits[0].sigma };
      const part = wk.slice(0, k).map((w) => w.v!);
      return { f: fits[k].predict([lag, part.reduce((s, v) => s + v, 0) / k - prevFull]), s: fits[k].sigma };
    };
    const kAt = (d: Date) => wk.filter((w) => w.v !== null && +w.rel <= +d).length;
    const path = Array.from({ length: nDays + 1 }, (_, i) => { const d = addDays(start, i); const k = kAt(d); const { f, s } = nowAt(k); return { d, k, f, lo: f - 1.645 * s, hi: f + 1.645 * s }; });
    const ref12 = new Date(y, m - 1, 12);
    const refA = addDays(ref12, -ref12.getDay()), refB = addDays(refA, 6);
    const lastRelease = noon(claimsRelease(lastWeek));
    return { start, end, nDays, wk, K, path, actual: dp.get(target) ?? null, lag, prevFull, refA, refB, lastRelease, nTrain: train.length, coef: fits[K].beta };
  });

  $effect(() => { target; stop(); day = 0; });
  const cur = $derived(model ? model.path[Math.min(day, model.nDays)] : null);
  const revealed = $derived(!!model && day >= model.nDays && model.actual !== null);
  const isFuture = (d: Date) => !!model && +d > +model.lastRelease + DAY;

  function stop() { clearInterval(timer); playing = false; }
  function play() {
    if (!model) return;
    if (reduceMotion()) { day = model.nDays; return; }
    if (day >= model.nDays) day = 0;
    playing = true; clearInterval(timer);
    timer = setInterval(() => { if (!model || day >= model.nDays) { stop(); return; } day += 1; }, 160);
  }
  onDestroy(() => clearInterval(timer));

  const k0 = (v: number) => `${v >= 0 ? '+' : '−'}${Math.abs(Math.round(v)).toLocaleString('en-US')}k`;

  function draw() {
    if (!model || !elCal || !elNow || !cur) return;
    const W = elCal.clientWidth, narrow = W < 640, ml = narrow ? 92 : 142, mr = narrow ? 70 : 92;
    const xd: [Date, Date] = [addDays(model.start, -0.6), addDays(model.end, 0.8)];
    const playhead = addDays(model.start, day);
    const lanes = narrow ? ['Claims (Thu)', 'Jobs (Fri)'] : ['Weekly claims (DOL)', 'Jobs report (BLS)'];
    const ev = [
      ...model.wk.map((w) => ({ lane: lanes[0], d: w.rel, txt: w.v !== null ? `${Math.round(w.v)}k` : '…', state: w.v === null ? 'future' : +w.rel <= +playhead ? 'in' : 'wait', w })),
      { lane: lanes[1], d: model.start, txt: 'last month', state: 'in' },
      { lane: lanes[1], d: model.end, txt: isFuture(model.end) ? 'not yet' : 'this month', state: isFuture(model.end) ? 'future' : revealed ? 'in' : 'wait' },
    ];
    const col = (s: string) => (s === 'in' ? C.forecast : s === 'future' ? C.border : C.muted);
    const days = Array.from({ length: model.nDays + 1 }, (_, i) => addDays(model.start, i));
    const cal = Plot.plot({
      width: W, height: 118, marginLeft: ml, marginRight: mr, marginTop: 22, marginBottom: 20, style: plotStyle(),
      x: { domain: xd, type: 'time', tickFormat: (d: Date) => dayFmt(d), ticks: Math.max(3, Math.floor(W / 120)) },
      y: { domain: lanes, label: null, tickSize: 0, axis: null },
      marks: [
        Plot.rectX([{ a: noon(model.refA), b: noon(model.refB) }], { x1: 'a', x2: 'b', fill: C.actual, fillOpacity: 0.12 }),
        Plot.text([{ d: noon(model.refA) }], { x: 'd', frameAnchor: 'top', dy: -16, textAnchor: 'start', text: () => 'reference week (incl. the 12th)', fill: C.text2, fontSize: 12 }),
        Plot.tickX(days, { x: (d: Date) => d, stroke: C.border, strokeOpacity: 0.7, inset: 6 }),
        Plot.text(lanes, { x: xd[0], y: (d: string) => d, text: (d: string) => d, textAnchor: 'end', dx: -6, fill: C.text2, fontSize: 12 }),
        Plot.dot(ev.filter((e) => e.state !== 'future'), { x: 'd', y: 'lane', r: 7, fill: (e: any) => (e.state === 'in' ? col('in') : 'none'), stroke: (e: any) => col(e.state), strokeWidth: 2 }),
        Plot.dot(ev.filter((e) => e.state === 'future'), { x: 'd', y: 'lane', r: 7, fill: 'none', stroke: C.muted, strokeWidth: 1.5, strokeDasharray: '2 2' }),
        Plot.text(ev, { x: 'd', y: 'lane', text: 'txt', dy: -14, fill: (e: any) => (e.state === 'in' ? C.text : C.muted), fontSize: 12, fontWeight: 600 }),
        Plot.ruleX([playhead], { stroke: C.actual, strokeWidth: 2 }),
        ...(isFuture(model.end) ? [Plot.rectX([{ a: model.lastRelease, b: xd[1] }], { x1: (d: any) => addDays(d.a, 0.5), x2: 'b', fill: C.border, fillOpacity: 0.25 }), Plot.text([{ d: xd[1] }], { x: 'd', frameAnchor: 'top', dy: -16, textAnchor: 'end', text: () => 'shaded: not published yet', fill: C.muted, fontSize: 12 })] : []),
      ],
    });
    cal.setAttribute('aria-label', `Release calendar for ${monthName(new Date(model.start))}: weekly claims every Thursday and the jobs report on ${dayFmt(model.end)}.`);
    elCal.replaceChildren(cal);

    const shown = model.path.slice(0, day + 1);
    const all = model.path.flatMap((p) => [p.lo, p.hi]).concat(model.actual !== null ? [model.actual] : []);
    const ext: [number, number] = [Math.min(...all, -100), Math.max(...all, 100)];
    const pad = (ext[1] - ext[0]) * 0.08;
    const marks: any[] = [
      Plot.ruleY([0], { stroke: C.borderStrong }),
      Plot.areaY(shown, { x: 'd', y1: 'lo', y2: 'hi', fill: C.forecast, fillOpacity: 0.16, curve: 'step-after' }),
      Plot.lineY(shown, { x: 'd', y: 'f', stroke: C.forecast, strokeWidth: 3, curve: 'step-after' }),
      Plot.ruleX([playhead], { stroke: C.actual, strokeWidth: 2 }),
      Plot.ruleX([cur], { x: 'd', y1: 'lo', y2: 'hi', stroke: C.forecast, strokeWidth: 7, strokeOpacity: 0.3 }),
      Plot.dot([cur], { x: 'd', y: 'f', r: 5, fill: C.forecast }),
      Plot.text([cur], { x: 'd', y: 'f', text: (p: any) => k0(p.f), dx: 10, textAnchor: 'start', fill: C.text, fontWeight: 700, fontSize: 13, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' } as any),
      Plot.text([cur], { x: 'd', y: 'hi', text: () => '90% band', dx: 10, dy: -2, textAnchor: 'start', fill: C.muted, fontSize: 12 }),
    ];
    if (revealed && model.actual !== null) marks.push(
      Plot.dot([{ d: model.end, v: model.actual }], { x: 'd', y: 'v', r: 7, fill: C.actual, stroke: C.surface, strokeWidth: 2 }),
      Plot.text([{ d: model.end, v: model.actual }], { x: 'd', y: 'v', text: (r: any) => `Actual ${k0(r.v)}`, dx: 10, dy: 14, textAnchor: 'start', fill: C.actual, fontWeight: 700, fontSize: 13, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' } as any),
    );
    const ch = Plot.plot({
      width: W, height: 260, marginLeft: ml, marginRight: mr, marginTop: 12, marginBottom: 28, style: plotStyle(),
      x: { domain: xd, type: 'time', tickFormat: (d: Date) => dayFmt(d), ticks: Math.max(3, Math.floor(W / 120)), label: null },
      y: { domain: [ext[0] - pad, ext[1] + pad], grid: true, label: 'Payroll change, thousands', tickFormat: (v: number) => v.toLocaleString('en-US') },
      marks,
    });
    ch.setAttribute('aria-label', `Nowcast of the ${monthName(targetDate)} payroll change: currently ${k0(cur.f)} with a 90% band from ${k0(cur.lo)} to ${k0(cur.hi)}.`);
    elNow.replaceChildren(ch);
  }

  $effect(() => { model; day; revealed; draw(); });
  onMount(() => { const a = watchLayout(elCal, draw); return a; });

  const tName = $derived(PRESETS.find((p) => p.key === target)?.label ?? target);
  const targetDate = $derived(new Date(+target.slice(0, 4), +target.slice(5) - 1, 1));
</script>

<Explorable title="The ragged edge: a nowcast that sharpens every Thursday" caption={`Press <b>Play</b> or drag the <b>date</b> slider. The clock starts when last month's jobs report comes out. Each Thursday the Labor Department publishes another week of initial jobless claims (seasonally adjusted, thousands). The bridge model re-estimates the month's payroll change with a separate regression for each number of weeks known, fit on 1990 to the month before (2020–21 excluded). The gold dot is the payroll change in today's revised data, not the first print. Data: FRED (ICSA, PAYEMS).`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Target month">
      {#each PRESETS as p}<button class:on={target === p.key} onclick={() => (target = p.key)}>{p.label}</button>{/each}
    </div>
    {#if model}
      <label class="sl">Date <input type="range" min="0" max={model.nDays} step="1" bind:value={day} oninput={stop} aria-valuetext={dayFmt(addDays(model.start, day))} /> <b>{dayFmt(addDays(model.start, day))}</b></label>
    {/if}
    <button class="btn btn-sm" onclick={() => (playing ? stop() : play())} aria-label={playing ? 'Pause' : 'Play the month'}>{playing ? '❚❚ Pause' : '▶ Play'}</button>
  {/snippet}
  {#snippet aside()}
    {#if model && cur}
      <div class="ro" aria-live="polite">
        <div class="eyebrow">Nowcast for {monthName(targetDate, true)} payrolls</div>
        <div class="big">{k0(cur.f)}</div>
        <div class="band">90% band {k0(cur.lo)} to {k0(cur.hi)}</div>
        <div class="kn">{cur.k} of {model.K} weeks of claims known{cur.k === 0 ? ': last month’s jobs number only' : ''}</div>
        <table>
          <thead><tr><th>Week ending</th><th>Claims</th><th>Out</th></tr></thead>
          <tbody>
            {#each model.wk as w}
              <tr class:in={w.v !== null && +w.rel <= +addDays(model.start, day)} class:fut={w.v === null}>
                <td>{dayFmt(w.end)}</td><td>{w.v !== null ? Math.round(w.v) + 'k' : '—'}</td><td>{w.v !== null ? dayFmt(w.rel) : 'not yet'}</td>
              </tr>
            {/each}
          </tbody>
        </table>
        {#if revealed && model.actual !== null}
          <p class="rev"><b>Jobs report day.</b> Actual {k0(model.actual)} (today's revised data). Miss: {k0(model.actual - cur.f)}.</p>
        {:else if model.actual === null}
          <p class="rev">This month's jobs report is due <b>{dayFmt(model.end)}</b>. Nobody knows the answer yet, not even the BLS.</p>
        {:else}
          <p class="rev muted">Play to the jobs report ({dayFmt(model.end)}) to reveal the answer.</p>
        {/if}
      </div>
    {/if}
  {/snippet}
  <div class="stack">
    <div bind:this={elCal} class="cal"></div>
    <div bind:this={elNow} class="nowc"></div>
  </div>
</Explorable>

<style>
  .stack { display: grid; gap: .2rem; }
  .cal { min-height: 118px; }
  .nowc { min-height: 260px; }
  .ro { font-size: .84rem; font-variant-numeric: tabular-nums; }
  .big { font: 700 2rem/1.1 var(--font-ui); color: var(--text); margin-top: .3rem; font-variant-numeric: tabular-nums; }
  .band { color: var(--text-2); }
  .kn { color: var(--muted); margin: .3rem 0 .6rem; font-size: .8rem; }
  table { width: 100%; font-size: .78rem; margin: 0 0 .6rem; }
  th, td { padding: .25rem .3rem; text-align: left; }
  tr.in td { color: var(--text); font-weight: 600; }
  tr.fut td { color: var(--muted); font-style: italic; }
  tr:not(.in):not(.fut) td { color: var(--muted); }
  .rev { margin: 0; color: var(--text-2); }
  .muted { color: var(--muted); }
</style>
