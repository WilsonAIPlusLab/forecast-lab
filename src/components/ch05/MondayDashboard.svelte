<script lang="ts">
  // Signature explorable 4: the Monday-morning batch run. 14 retail categories, one ETS(M,Ad,M) each,
  // backtested on the last 12 months and sorted into a traffic-light exception report.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, futureDates, ym, type Pt } from '../../lib/ts';
  import { C, plotStyle, fmt, watchLayout } from '../../lib/viz/theme';
  import { etsFit, etsFilter, etsForecast, mase, mape, type EtsPar } from './models';
  import { status } from './viz'; // also registers the ch05-multiples chart type for the code lab

  const CATS: [string, string][] = [
    ['441', 'Motor vehicles & parts'], ['442', 'Furniture'], ['443', 'Electronics & appliances'], ['444', 'Building materials'],
    ['445', 'Food & beverage stores'], ['446', 'Health & personal care'], ['447', 'Gasoline stations'], ['448', 'Clothing'],
    ['451', 'Sporting goods & hobby'], ['452', 'General merchandise'], ['453', 'Misc. store retailers'], ['454', 'Nonstore retailers'],
    ['4541', 'E-commerce'], ['722', 'Food services & drinking'],
  ];
  interface Row {
    code: string; name: string; data: Pt[]; par: EtsPar; mase: number; mape: number;
    back: number[]; backDates: Date[]; fwd: { mean: number[]; lo: number[]; hi: number[] }; fwdDates: Date[]; ms: number;
  }
  let rows: Row[] = $state([]);
  let sortBy: 'mase' | 'name' = $state('mase');
  let view: 'back' | 'next' = $state('back');
  let sel = $state('453');
  let runMs = $state(0);
  let detail: HTMLDivElement | undefined = $state();

  onMount(async () => {
    const t0 = performance.now();
    const out: Row[] = [];
    for (const [code, name] of CATS) {
      const s = await loadSeries(`MRTSSM${code}USN`, { start: '2015-01-01' });
      const y = s.data.map((p) => p.value), n = y.length;
      const tr = y.slice(0, n - 12), te = y.slice(n - 12);
      const t1 = performance.now();
      const fit = etsFit(tr, 12);
      const back = etsForecast(fit.state, 12, fit.par, fit.sigma!, 12, tr.length).mean;
      // production run: same parameters, states carried through the 12 newest months
      const upd = etsFilter(te, 12, fit.par, { ...fit.state, s: rotate(fit.state.s, tr.length % 12) });
      const fwd = etsForecast({ ...upd.state, s: rotate(upd.state.s, -(tr.length % 12)) }, 12, fit.par, fit.sigma!, 12, n);
      out.push({ code, name, data: s.data, par: fit.par, mase: mase(te, back, tr, 12), mape: mape(te, back), back,
        backDates: s.data.slice(n - 12).map((p) => p.date), fwd, fwdDates: futureDates(s.data[n - 1].date, 12, 12), ms: performance.now() - t1 });
    }
    rows = out;
    runMs = performance.now() - t0;
  });
  // etsFilter indexes seasons by t % 12 from t = 0; re-align when restarting mid-series
  function rotate(s: number[], k: number) { const m = s.length; return s.map((_, i) => s[(((i + k) % m) + m) % m]); }

  const sorted = $derived(sortBy === 'mase' ? [...rows].sort((a, b) => b.mase - a.mase) : [...rows].sort((a, b) => a.name.localeCompare(b.name)));
  const counts = $derived(rows.reduce((c, r) => { c[status(r.mase).k]++; return c; }, { ok: 0, watch: 0, review: 0 } as Record<string, number>));
  const cur = $derived(rows.find((r) => r.code === sel));

  // tiny SVG sparkline geometry
  const TW = 160, TH = 54;
  function spark(r: Row) {
    const n = r.data.length;
    const hist = r.data.slice(n - 44, view === 'back' ? n - 12 : n).map((p) => p.value);
    const act = view === 'back' ? r.data.slice(n - 13).map((p) => p.value) : [];
    const fc = view === 'back' ? [r.data[n - 13].value, ...r.back] : [r.data[n - 1].value, ...r.fwd.mean];
    const lo = view === 'next' ? r.fwd.lo : [], hi = view === 'next' ? r.fwd.hi : [];
    const all = [...hist, ...act, ...fc, ...lo, ...hi];
    const mn = Math.min(...all), mx = Math.max(...all);
    const total = view === 'back' ? 44 : 56;
    const X = (i: number) => 2 + (i / (total - 1)) * (TW - 4), Y = (v: number) => TH - 3 - ((v - mn) / (mx - mn || 1)) * (TH - 6);
    const path = (vals: number[], i0: number) => vals.map((v, i) => `${i ? 'L' : 'M'}${X(i0 + i).toFixed(1)},${Y(v).toFixed(1)}`).join('');
    const i0 = hist.length - 1;
    const band = lo.length ? `M${lo.map((v, i) => `${X(i0 + 1 + i).toFixed(1)},${Y(v).toFixed(1)}`).join('L')}L${hi.map((v, i) => `${X(i0 + 1 + i).toFixed(1)},${Y(v).toFixed(1)}`).reverse().join('L')}Z` : '';
    return { hist: path(hist, 0), act: act.length ? path(act, i0) : '', fc: path(fc, i0), band, ox: X(i0) };
  }

  function drawDetail() {
    if (!detail || !cur) return;
    const r = cur, n = r.data.length, W = Math.max(200, detail.clientWidth || 260);   // width floor: avoids negative bars mid-resize
    const hist = r.data.slice(n - 48);
    const back = r.back.map((v, i) => ({ date: r.backDates[i], v }));
    const fwd = r.fwd.mean.map((v, i) => ({ date: r.fwdDates[i], v, lo: r.fwd.lo[i], hi: r.fwd.hi[i] }));
    detail.replaceChildren(Plot.plot({
      width: W, height: 220, marginLeft: 44, marginRight: 8, marginTop: 10, marginBottom: 24,
      style: { ...plotStyle(), fontSize: '12px' }, x: { label: null, ticks: 3 }, y: { grid: true, nice: true, label: null, tickFormat: (d: number) => `${Math.round(d / 1000)}k`, ticks: 4 },
      ariaLabel: `${r.name}: backtest and next-12-month forecast`,
      marks: [
        Plot.areaY(fwd, { x: 'date', y1: 'lo', y2: 'hi', fill: C.forecast, fillOpacity: 0.22 }),
        Plot.lineY(hist, { x: 'date', y: 'value', stroke: C.history, strokeWidth: 1.6 }),
        Plot.lineY(r.data.slice(n - 13), { x: 'date', y: 'value', stroke: C.actual, strokeWidth: 2 }),
        Plot.lineY(back, { x: 'date', y: 'v', stroke: C.fitted, strokeWidth: 2, strokeDasharray: '4 3' }),
        Plot.lineY(fwd, { x: 'date', y: 'v', stroke: C.forecast, strokeWidth: 2.5 }),
        Plot.ruleX([r.backDates[0]], { stroke: C.borderStrong, strokeDasharray: '3 4' }),
        Plot.tip([...hist.map((p) => ({ date: p.date, a: p.value })), ...fwd.map((p) => ({ date: p.date, f: p.v, lo: p.lo, hi: p.hi }))], Plot.pointerX({ x: 'date', y: (d: any) => d.a ?? d.f, title: (d: any) => d.a != null ? `${ym(d.date)}\nActual: ${fmt(d.a)} $ mn` : `${ym(d.date)}\nForecast: ${fmt(d.f)} $ mn\n80% interval: ${fmt(d.lo)}–${fmt(d.hi)}` })),
      ],
    }));
  }
  $effect(() => { cur; drawDetail(); });
  $effect(() => { if (detail) return watchLayout(detail, drawDetail); });
</script>

<Explorable wide title="Monday morning: 14 forecasts, one exception report" caption={`Each tile is a U.S. retail category ($ millions, <b>not seasonally adjusted</b>, Census monthly retail trade via FRED, MRTSSM441USN…MRTSSM722USN). For each one, the page fits an ETS(M,Ad,M) model on data through Aug 2025, forecasts the 12 months to Aug 2026, and scores that <b>backtest</b> with MASE. Badges: <b>OK</b> below 0.8, <b>Watch</b> 0.8–1, <b>Review</b> above 1. Click a tile for detail. This JavaScript version picks parameters by a coarse grid search on the ETS likelihood, so its MASE values differ a little from R's <code>ets()</code> in the lab below.`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Sort tiles">
      <button class:on={sortBy === 'mase'} onclick={() => (sortBy = 'mase')}>Worst first</button>
      <button class:on={sortBy === 'name'} onclick={() => (sortBy = 'name')}>A–Z</button>
    </div>
    <div class="seg" role="group" aria-label="What the tiles show">
      <button class:on={view === 'back'} onclick={() => (view = 'back')}>Backtest vs actual</button>
      <button class:on={view === 'next'} onclick={() => (view = 'next')}>Next 12 months</button>
    </div>
    {#if rows.length}<span class="tally" aria-live="polite"><b class="t-ok">{counts.ok} OK</b> · <b class="t-watch">{counts.watch} Watch</b> · <b class="t-review">{counts.review} Review</b> · fitted in {Math.round(runMs)} ms</span>{/if}
  {/snippet}
  {#snippet aside()}
    {#if cur}
      <div class="det">
        <div class="det-h">{cur.name}</div>
        <div class="det-s">NAICS {cur.code} · <span class="b-{status(cur.mase).k}">{status(cur.mase).label}</span></div>
        <div bind:this={detail} class="det-chart"></div>
        <dl>
          <dt>Backtest MASE</dt><dd>{cur.mase.toFixed(2)}</dd>
          <dt>Backtest MAPE</dt><dd>{cur.mape.toFixed(1)}%</dd>
          <dt>α, β, γ, φ</dt><dd>{cur.par.alpha}, {cur.par.beta}, {cur.par.gamma}, {cur.par.phi}</dd>
        </dl>
        <p class="det-n">Gold: what actually happened, Sep 2025–Aug 2026. Cyan dashed: what the model forecast for those months. Purple: the production forecast for the next 12 months, with an 80% interval from 300 simulated paths.</p>
      </div>
    {:else}
      <p class="det-n">Fitting 14 models…</p>
    {/if}
  {/snippet}
  {#if !rows.length}
    <div class="loading">Loading 14 series and fitting models…</div>
  {:else}
    <div class="grid">
      {#each sorted as r (r.code)}
        {@const g = spark(r)}
        {@const st = status(r.mase)}
        <button class="tile" class:sel={sel === r.code} onclick={() => (sel = r.code)} aria-label={`${r.name}: backtest MASE ${r.mase.toFixed(2)}, ${st.label}`}>
          <span class="t-top"><span class="t-name">{r.name}</span><span class="badge b-{st.k}">{st.label} {r.mase.toFixed(2)}</span></span>
          <svg viewBox={`0 0 ${TW} ${TH}`} width="100%" height={TH} aria-hidden="true">
            {#if g.band}<path d={g.band} class="sp-band" />{/if}
            <line x1={g.ox} x2={g.ox} y1="0" y2={TH} class="sp-o" />
            <path d={g.hist} class="sp-h" />
            {#if g.act}<path d={g.act} class="sp-a" />{/if}
            <path d={g.fc} class={view === 'back' ? 'sp-b' : 'sp-f'} />
          </svg>
        </button>
      {/each}
    </div>
  {/if}
</Explorable>

<style>
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 8px; }
  .tile { all: unset; box-sizing: border-box; cursor: pointer; display: flex; flex-direction: column; gap: 4px; padding: 7px 8px 4px; border: 1px solid var(--border); border-radius: 8px; background: var(--bg-2); }
  .tile:hover { border-color: var(--border-strong); }
  .tile.sel { border-color: var(--ch, var(--accent)); box-shadow: 0 0 0 1px var(--ch, var(--accent)) inset; }
  .tile:focus-visible { outline: 2px solid var(--accent-2); outline-offset: 2px; }
  .t-top { display: flex; justify-content: space-between; align-items: flex-start; gap: 4px; font-size: 12px; line-height: 1.25; min-height: 2.5em; }
  .t-name { color: var(--text); font-weight: 600; }
  .badge { flex: none; font-weight: 700; font-variant-numeric: tabular-nums; padding: 0 .3rem; border-radius: 4px; }
  .b-ok { color: var(--good); } .b-watch { color: var(--warm); } .b-review { color: var(--danger); }
  .badge.b-ok { background: color-mix(in srgb, var(--good) 12%, transparent); }
  .badge.b-watch { background: color-mix(in srgb, var(--warm) 14%, transparent); }
  .badge.b-review { background: color-mix(in srgb, var(--danger) 14%, transparent); }
  .sp-h { fill: none; stroke: var(--c-history); stroke-width: 1.3; }
  .sp-a { fill: none; stroke: var(--c-actual); stroke-width: 1.8; stroke-dasharray: 3 2; }
  .sp-b { fill: none; stroke: var(--c-fitted); stroke-width: 2; }
  .sp-f { fill: none; stroke: var(--c-forecast); stroke-width: 2; }
  .sp-band { fill: var(--c-forecast); opacity: .22; }
  .sp-o { stroke: var(--border-strong); stroke-dasharray: 2 3; }
  .tally { font-size: .8rem; color: var(--muted); font-variant-numeric: tabular-nums; }
  .t-ok { color: var(--good); } .t-watch { color: var(--warm); } .t-review { color: var(--danger); }
  .loading { padding: 3rem 0; text-align: center; color: var(--muted); }
  .det { font-size: .82rem; }
  .det-h { font-weight: 650; color: var(--text); font-size: .95rem; }
  .det-s { color: var(--muted); margin-bottom: .4rem; font-weight: 600; }
  .det-chart { min-height: 220px; }
  dl { display: grid; grid-template-columns: auto 1fr; gap: .2rem .8rem; margin: .5rem 0; }
  dt { color: var(--muted); } dd { margin: 0; font-variant-numeric: tabular-nums; color: var(--text); text-align: right; }
  .det-n { color: var(--muted); font-size: .78rem; line-height: 1.5; margin: 0; }
</style>
