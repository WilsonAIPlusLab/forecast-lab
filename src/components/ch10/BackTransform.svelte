<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, futureDates } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { fitETS, forecast, sdH, qnorm, type Spec } from './models';

  // "Logs in, dollars out": a forecast made in logs is a symmetric bell in log units.
  // Transform it back with exp() and the bell leans right: exp(point) is the MEDIAN,
  // the mean sits higher (by about sigma^2/2), and the band's endpoints transform cleanly but unevenly.
  const H = 24, Z80 = qnorm(0.9);
  const SERIES = {
    oil: { label: 'Crude oil (volatile)', id: 'DCOILWTICO', start: '2015-01-01', end: '2026-10-01', to: 'month' as const, spec: { m: 1, trend: false, season: false } as Spec, scale: 1,
      unit: '$ per barrel', long: 'WTI crude oil (DCOILWTICO), monthly average of daily prices, $ per barrel, January 2015 to October 2026; simple exponential smoothing on the log price' },
    retail: { label: 'Retail sales (calm)', id: 'RSXFSN', start: '2022-01-01', end: undefined, to: undefined, spec: { m: 12, trend: true, season: true } as Spec, scale: 1000,
      unit: '$ billions', long: 'U.S. retail sales excl. food services (RSXFSN, NSA), $ billions per month, January 2022 on; exponential smoothing with trend and seasonality on log sales' },
  };
  type SID = keyof typeof SERIES;
  let sid: SID = $state('oil');
  let h = $state(12);
  let view: 'log' | 'dollar' = $state('dollar');
  let base: { hist: { date: Date; value: number }[]; dates: Date[]; mu: number[]; sd: number[] } | null = $state.raw(null);
  let el: HTMLDivElement, el2: HTMLDivElement;

  async function load() {
    const cfg = SERIES[sid];
    const s = await loadSeries(cfg.id, { start: cfg.start, end: cfg.end, to: cfg.to });
    const fit = fitETS(s.data.map((p) => Math.log(p.value / cfg.scale)), cfg.spec);
    base = { hist: s.data.map((p) => ({ date: p.date, value: p.value / cfg.scale })), dates: futureDates(s.data[s.data.length - 1].date, H, 12), mu: forecast(fit, H), sd: sdH(fit, H) };
  }
  // summary of the forecast distribution at horizon index k
  const at = (k: number) => {
    const m = base!.mu[k], s = base!.sd[k];
    return { m, s, med: Math.exp(m), mean: Math.exp(m + (s * s) / 2), lo: Math.exp(m - Z80 * s), hi: Math.exp(m + Z80 * s), llo: m - Z80 * s, lhi: m + Z80 * s };
  };
  const cur = $derived.by(() => (base ? { ...at(h - 1), date: base.dates[h - 1] } : null));
  const money = (v: number) => (sid === 'oil' ? `$${v.toFixed(2)}` : `$${v.toFixed(1)} bn`);

  function draw() {
    if (!el || !base || !cur) return;
    const W = el.clientWidth, L = view === 'log';
    const tf = (v: number) => (L ? Math.log(v) : v);          // values to the chosen axis
    const last = base.hist[base.hist.length - 1];
    const rows = base.dates.map((d, k) => { const a = at(k); return { date: d, med: L ? a.m : a.med, mean: L ? a.m : a.mean, lo: L ? a.llo : a.lo, hi: L ? a.lhi : a.hi }; });
    const anc = { date: last.date, med: tf(last.value), mean: tf(last.value), lo: tf(last.value), hi: tf(last.value) };
    const sel = rows[h - 1];
    el.replaceChildren(Plot.plot({
      width: W, height: Math.max(250, Math.min(320, W * 0.4)), marginLeft: 52, marginRight: 64, marginTop: 18, style: plotStyle(),
      x: { label: null },
      y: { grid: true, label: L ? `↑ log(${SERIES[sid].unit})` : `↑ ${SERIES[sid].unit}`, tickFormat: L ? (v: number) => v.toFixed(2) : undefined },
      marks: [
        Plot.areaY([anc, ...rows], { x: 'date', y1: 'lo', y2: 'hi', fill: C.forecast, fillOpacity: 0.22 }),
        Plot.lineY(base.hist.slice(-48).map((p) => ({ date: p.date, v: tf(p.value) })), { x: 'date', y: 'v', stroke: C.history, strokeWidth: 1.8 }),
        Plot.lineY([anc, ...rows], { x: 'date', y: 'med', stroke: C.forecast, strokeWidth: 2.4 }),
        L ? null : Plot.lineY([anc, ...rows], { x: 'date', y: 'mean', stroke: C.actual, strokeWidth: 2.2, strokeDasharray: '6,4' }),
        Plot.text([rows[H - 1]], { x: 'date', y: 'med', text: () => (L ? 'point' : 'median'), dx: 6, dy: L ? 0 : 8, textAnchor: 'start', fill: C.text2, fontSize: 12 }),
        L ? null : Plot.text([rows[H - 1]], { x: 'date', y: 'mean', text: () => 'mean', dx: 6, dy: -6, textAnchor: 'start', fill: C.text2, fontSize: 12, fontWeight: 600 }),
        Plot.ruleX([sel.date], { stroke: C.text2, strokeDasharray: '3,3' }),
        Plot.tip(rows, Plot.pointerX({ x: 'date', y: 'med', title: (r: any) => L
          ? `${r.date.toLocaleDateString('en-US', { month: 'short', year: 'numeric' })}\nLog point: ${r.med.toFixed(3)}\n80% band: ${r.lo.toFixed(3)} to ${r.hi.toFixed(3)} (symmetric)`
          : `${r.date.toLocaleDateString('en-US', { month: 'short', year: 'numeric' })}\nMedian: ${money(r.med)} · Mean: ${money(r.mean)}\n80% band: ${money(r.lo)} to ${money(r.hi)}` })),
      ],
    }));
    // the forecast distribution for the chosen month
    const { m, s } = cur;
    const N = 160;
    const pts = L
      ? Array.from({ length: N }, (_, i) => { const x = m - 3.5 * s + (7 * s * i) / (N - 1); return { x, d: Math.exp(-((x - m) ** 2) / (2 * s * s)) / (s * Math.sqrt(2 * Math.PI)) }; })
      : Array.from({ length: N }, (_, i) => { const x = Math.exp(m - 3 * s) + ((Math.exp(m + 3.3 * s) - Math.exp(m - 3 * s)) * i) / (N - 1); return { x, d: Math.exp(-((Math.log(x) - m) ** 2) / (2 * s * s)) / (x * s * Math.sqrt(2 * Math.PI)) }; });
    const lo = L ? cur.llo : cur.lo, hi = L ? cur.lhi : cur.hi, md = L ? m : cur.med, mn = L ? m : cur.mean;
    const top = Math.max(...pts.map((p) => p.d));
    const lab = (x: number, t: string, anchor: 'start' | 'end', dy: number) => Plot.text([{ x }], { x: 'x', y: () => top * dy, text: () => t, textAnchor: anchor, dx: anchor === 'start' ? 5 : -5, fill: C.text, fontSize: 12, fontWeight: 600, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' });
    el2.replaceChildren(Plot.plot({
      width: W, height: 200, marginLeft: 52, marginRight: 24, marginTop: 14, marginBottom: 38, style: plotStyle(),
      x: { label: L ? `log(${SERIES[sid].unit}) →` : `${SERIES[sid].unit} →`, tickFormat: L ? (v: number) => v.toFixed(2) : undefined },
      y: { axis: null },
      marks: [
        Plot.areaY(pts.filter((p) => p.x >= lo && p.x <= hi), { x: 'x', y: 'd', fill: C.forecast, fillOpacity: 0.28 }),
        Plot.lineY(pts, { x: 'x', y: 'd', stroke: C.forecast, strokeWidth: 2 }),
        Plot.ruleY([0], { stroke: C.borderStrong }),
        Plot.ruleX([md], { stroke: C.forecast, strokeWidth: 2.4 }),
        L ? null : Plot.ruleX([mn], { stroke: C.actual, strokeWidth: 2.2, strokeDasharray: '6,4' }),
        L ? lab(md, 'point = median = mean', 'start', 1.02) : lab(md, 'median', 'end', 1.02),
        L ? null : lab(mn, 'mean', 'start', 0.88),
        Plot.text([{ x: lo }], { x: 'x', y: () => top * 0.08, text: () => '10% below', textAnchor: 'end', dx: -4, fill: C.muted, fontSize: 12 }),
        Plot.text([{ x: hi }], { x: 'x', y: () => top * 0.08, text: () => '10% above', textAnchor: 'start', dx: 4, fill: C.muted, fontSize: 12 }),
      ],
    }));
  }

  $effect(() => { sid; load(); });
  $effect(() => { base; h; view; draw(); });
  onMount(() => watchLayout(el, draw));
</script>

<Explorable title="Logs in, dollars out: the back-transformed point is a median, not a mean"
  caption={`The model forecasts the <b>log</b> of the series, where the forecast distribution is a symmetric bell. Switch the view between <b>log units</b> and <b>dollars</b>, and drag the horizon. Violet solid: the back-transformed point forecast, exp(log forecast), which is the median. Gold dashed: the mean. Shaded: the 80% band, whose endpoints are simply exp() of the log endpoints. Data: ${SERIES[sid].long}.`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Series">
      {#each Object.entries(SERIES) as [k, x]}<button class:on={sid === k} aria-pressed={sid === k} onclick={() => (sid = k as SID)}>{x.label}</button>{/each}
    </div>
    <div class="seg" role="group" aria-label="Units">
      <button class:on={view === 'log'} aria-pressed={view === 'log'} onclick={() => (view = 'log')}>Log units</button>
      <button class:on={view === 'dollar'} aria-pressed={view === 'dollar'} onclick={() => (view = 'dollar')}>Dollars</button>
    </div>
    <label class="sl">Months ahead <input type="range" min="1" max={H} step="1" bind:value={h} aria-valuetext={`${h} months ahead`} /> <b>{h}</b></label>
  {/snippet}
  {#snippet aside()}
    {#if cur}
      <div class="ro" aria-live="polite">
        <p class="when">{cur.date.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}, {h} month{h > 1 ? 's' : ''} ahead</p>
        {#if view === 'log'}
          <p>In logs the forecast is <b>{cur.m.toFixed(3)} ± {(Z80 * cur.s).toFixed(3)}</b> (80%). The bell is symmetric, so the point is the median <i>and</i> the mean.</p>
          <p>A log spread of {cur.s.toFixed(3)} means a typical miss of roughly <b>{(100 * cur.s).toFixed(0)}%</b>.</p>
          <p class="hint">Switch to dollars to see what exp() does to this bell.</p>
        {:else}
          <table>
            <tbody>
              <tr><td>Median = exp(point)</td><td>{money(cur.med)}</td></tr>
              <tr><td>Mean</td><td>{money(cur.mean)}</td></tr>
              <tr class="on"><td>Mean above median</td><td>+{(100 * (cur.mean / cur.med - 1)).toFixed(1)}%</td></tr>
              <tr><td>80% band</td><td>{money(cur.lo)} to {money(cur.hi)}</td></tr>
            </tbody>
          </table>
          <p>The band reaches <b>{money(cur.med - cur.lo)}</b> below the median but <b>{money(cur.hi - cur.med)}</b> above it.</p>
          <p class="hint">{(100 * (cur.mean / cur.med - 1)) < 1 ? 'Here the gap is tiny: for a calm series the median and mean are practically the same.' : 'A large gap: for budgets that add up across months, report the mean; for a "typical" outcome, the median.'}</p>
        {/if}
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} role="img" aria-label="Forecast fan for the chosen series with the median line and, in dollar view, the higher mean line"></div>
  <div bind:this={el2} role="img" aria-label="Forecast distribution for the chosen month: symmetric in log units, skewed to the right in dollars, with median and mean marked"></div>
</Explorable>

<style>
  .ro { font-size: .86rem; color: var(--text-2); display: grid; gap: .55rem; }
  .ro p { margin: 0; }
  .ro b { color: var(--text); font-variant-numeric: tabular-nums; }
  .when { font-weight: 650; color: var(--text); }
  .ro table { margin: 0; font-size: .8rem; }
  .ro td { padding: .28rem .35rem; font-variant-numeric: tabular-nums; }
  .ro td:last-child { text-align: right; }
  .ro tr.on td { color: var(--text); font-weight: 650; }
  .hint { color: var(--muted); font-size: .8rem; }
</style>
