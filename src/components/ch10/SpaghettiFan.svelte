<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, futureDates, rng, ym } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { fitETS, simulate, quantile } from './models';
  import './viz';

  // "From spaghetti to fan": simulate futures from December 2019 one by one, then collapse them into quantile bands.
  const H = 24, NSHOW = 50, NMANY = 2000;
  let el: HTMLDivElement;
  let hist: { date: Date; value: number }[] = $state([]);
  let actual: { date: Date; value: number }[] = $state([]);
  let dates: Date[] = $state([]);
  let paths: number[][] = $state([]);          // NSHOW display paths ($ bn)
  let many: number[][] = $state.raw([]);        // NMANY paths for the quantiles
  let fit: any = null;
  let lastView = 'paths', animateFan = false;
  let shown = $state(0);
  let view: 'paths' | 'fan' | 'actual' = $state('paths');
  let level = $state(80);
  let timer: any;
  let seed = 2026;
  const reduce = () => typeof window !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches;

  async function load() {
    const s = await loadSeries('RSXFSN', { start: '2010-01-01', end: '2021-12-01' });
    const tr = s.data.filter((p) => p.date < new Date('2020-01-01T00:00:00'));
    actual = s.data.filter((p) => p.date >= new Date('2020-01-01T00:00:00')).map((p) => ({ date: p.date, value: p.value / 1000 }));
    hist = tr.filter((p) => p.date >= new Date('2017-01-01T00:00:00')).map((p) => ({ date: p.date, value: p.value / 1000 }));
    fit = fitETS(tr.map((p) => Math.log(p.value)), { m: 12, trend: true, season: true });
    dates = futureDates(tr[tr.length - 1].date, H, 12);
    const r = rng(7);
    many = Array.from({ length: NMANY }, () => simulate(fit, H, r.u, fit.resid).map((v) => Math.exp(v) / 1000));
    resample();
  }
  function resample() {
    if (!fit) return;
    const r = rng(seed++);
    paths = Array.from({ length: NSHOW }, () => simulate(fit, H, r.u, fit.resid).map((v) => Math.exp(v) / 1000));
  }
  function run() {
    clearInterval(timer); view = 'paths'; resample();
    if (reduce()) { shown = NSHOW; return; }
    shown = 0;
    timer = setInterval(() => { shown += 1; if (shown >= NSHOW) clearInterval(timer); }, 45);
  }

  const bands = $derived.by(() => {
    if (!many.length || !dates.length) return null;
    const a = (1 - level / 100) / 2;
    return dates.map((d, k) => { const col = many.map((p) => p[k]); return { date: d, lo: quantile(col, a), hi: quantile(col, 1 - a), mid: quantile(col, 0.5) }; });
  });
  const stats = $derived.by(() => {
    if (!bands || !paths.length) return null;
    const k = H - 1, b = bands[k];
    const outPaths = paths.slice(0, Math.max(shown, 1)).filter((p) => p[k] < b.lo || p[k] > b.hi).length;
    const inAct = actual.slice(0, H).filter((p, i) => p.value >= bands[i].lo && p.value <= bands[i].hi).length;
    return { b, outPaths, inAct, apr: actual[3], aprBand: bands[3] };
  });

  function draw() {
    if (!el || !hist.length || !bands) return;
    const last = hist[hist.length - 1];
    const fc = C.forecast, W = el.clientWidth;
    const show = paths.slice(0, shown).flatMap((p, k) => [{ date: last.date, v: last.value, k }, ...p.map((v, i) => ({ date: dates[i], v, k }))]);
    const band = [{ date: last.date, lo: last.value, hi: last.value }, ...bands];
    const fan = view !== 'paths';
    animateFan = fan && lastView === 'paths' && !reduce(); lastView = view;
    const ys = [...hist.map((d) => d.value), ...actual.map((d) => d.value), ...many.map((p) => p[H - 1]).sort((a, b) => a - b).filter((_, i, A) => i > A.length * 0.003 && i < A.length * 0.997)];
    const marks: any[] = [
      Plot.ruleX([last.date], { stroke: C.borderStrong, strokeDasharray: '3,4' }),
      Plot.text([last.date], { x: (d: any) => d, frameAnchor: 'top', dx: 6, dy: 2, textAnchor: 'start', text: () => 'December 2019: forecast starts', fill: C.muted, fontSize: 12 }),
      Plot.lineY(show, { x: 'date', y: 'v', z: 'k', stroke: fc, strokeOpacity: fan ? 0.1 : 0.4, strokeWidth: fan ? 1 : 1.25 }),
    ];
    if (fan) marks.push(
      Plot.areaY(band, { x: 'date', y1: 'lo', y2: 'hi', fill: fc, fillOpacity: 0.28, className: animateFan ? 'ch10-fanin' : undefined }),
      Plot.lineY([{ date: last.date, mid: last.value }, ...bands], { x: 'date', y: 'mid', stroke: fc, strokeWidth: 2.5 }),
      Plot.text([bands[H - 1]], { x: 'date', y: 'hi', text: () => `${level}% band`, dx: 6, textAnchor: 'start', fill: C.text2, fontSize: 12, fontWeight: 600 }),
    );
    marks.push(Plot.lineY(hist, { x: 'date', y: 'value', stroke: C.history, strokeWidth: 2.2 }));
    if (view === 'actual') marks.push(
      Plot.lineY([last, ...actual], { x: 'date', y: 'value', stroke: C.actual, strokeWidth: 2.6, strokeDasharray: '5,3' }),
      Plot.dot(actual, { x: 'date', y: 'value', r: 3.2, fill: (d: any, i: number) => (d.value >= bands[i].lo && d.value <= bands[i].hi ? C.actual : C.danger), stroke: C.surface, strokeWidth: 1 }),
      Plot.text([actual[3]], { x: 'date', y: 'value', text: () => 'April 2020', dy: 14, fill: C.text, fontSize: 12, fontWeight: 600, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
    );
    const tipRows = fan ? bands.map((b, i) => ({ ...b, a: actual[i]?.value })) : [];
    if (fan) marks.push(Plot.tip(tipRows, Plot.pointerX({ x: 'date', y: 'mid', title: (r: any) => `${ym(r.date)}\n${level}% band: $${r.lo.toFixed(0)}–${r.hi.toFixed(0)} bn${view === 'actual' && r.a ? `\nActual: $${r.a.toFixed(0)} bn` : ''}` })));
    el.replaceChildren(Plot.plot({
      width: W, height: Math.max(300, Math.min(420, W * 0.52)), marginLeft: 52, marginRight: 70, marginTop: 22, style: plotStyle(),
      x: { label: null }, y: { grid: true, label: '↑ Monthly retail sales ($ billions)', domain: [Math.min(...ys) * 0.98, Math.max(...ys) * 1.02] },
      marks,
    }));
  }

  $effect(() => { shown; view; level; bands; paths; draw(); });
  onMount(() => { load().then(() => { if (reduce()) shown = NSHOW; else run(); }); return watchLayout(el, draw); });
  onDestroy(() => clearInterval(timer));
  const bn = (v: number) => `$${v.toFixed(0)} bn`;
</script>

<Explorable title="From spaghetti to fan: an interval is a summary of many possible futures"
  caption="Each thin violet line is one future the model considers possible, built by replaying its own past one-month errors in random order. Press <b>Simulate 50 futures</b> to draw a fresh set. Switch to <b>Fan</b>: at each month, the band keeps the middle share of 2,000 such paths. Then reveal <b>what happened</b>. Model: additive exponential smoothing on log sales (trend + seasonality), fitted to U.S. retail sales excluding food services, 2010–2019 (RSXFSN, NSA, shown in $ billions per month).">
  {#snippet controls()}
    <button class="btn btn-sm" onclick={run}>Simulate 50 futures</button>
    <div class="seg" role="group" aria-label="View">
      <button class:on={view === 'paths'} onclick={() => (view = 'paths')}>Paths</button>
      <button class:on={view === 'fan'} onclick={() => (view = 'fan')}>Fan</button>
      <button class:on={view === 'actual'} onclick={() => (view = 'actual')}>Fan + what happened</button>
    </div>
    <label class="sl">Interval level <input type="range" min="50" max="99" step="1" bind:value={level} aria-valuetext={`${level} percent`} /> <b>{level}%</b></label>
  {/snippet}
  {#snippet aside()}
    {#if stats}
      <div class="ro" aria-live="polite">
        <div class="stat"><span class="stat-v">{shown}</span><span class="stat-l">futures drawn</span></div>
        <p>In December 2021, the {level}% band runs from <b>{bn(stats.b.lo)}</b> to <b>{bn(stats.b.hi)}</b>.</p>
        <p><b>{stats.outPaths}</b> of the {Math.max(shown, 1)} drawn paths end outside it. You would expect about {Math.round(Math.max(shown, 1) * (1 - level / 100))}.</p>
        {#if view === 'actual'}
          <p class="hit">Only <b>{stats.inAct} of 24</b> actual months landed inside the {level}% band. April 2020 came in at {bn(stats.apr.value)}, far below the band's floor of {bn(stats.aprBand.lo)}.</p>
        {:else}
          <p class="hint">Before you reveal 2020–2021: how many of the 24 real months do you think land inside the 95% band?</p>
        {/if}
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart" role="img" aria-label="Simulated future paths of U.S. retail sales from December 2019 and the fan chart they form"></div>
</Explorable>

<style>
  .chart { min-height: 300px; }
  .ro { font-size: .86rem; color: var(--text-2); display: grid; gap: .55rem; }
  .ro p { margin: 0; }
  .ro b { color: var(--text); font-variant-numeric: tabular-nums; }
  .hit { border-left: 3px solid var(--danger); padding-left: .6rem; }
  .hint { color: var(--muted); font-size: .8rem; }
  .chart :global(.ch10-fanin) { animation: ch10fade .4s cubic-bezier(.2,0,0,1) both; }
  @keyframes ch10fade { from { opacity: 0; } to { opacity: 1; } }
  @media (prefers-reduced-motion: reduce) { .chart :global(.ch10-fanin) { animation: none; } }
</style>
