<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, fcMean, fcNaive, fcSNaive, fcDrift, accuracy, futureDates, ym, type Series } from '../../lib/ts';
  import { C, plotStyle, fmt, watchLayout } from '../../lib/viz/theme';

  const SERIES = [
    { id: 'RSXFSN', label: 'Retail sales', unit: '$ millions' },
    { id: 'HOUST', label: 'Housing starts', unit: 'thousands, SAAR' },
    { id: 'UNRATE', label: 'Unemployment rate', unit: '%' },
    { id: 'MRTSSM4541USS', label: 'Online retail', unit: '$ millions' },
  ];
  const METHODS = [
    { k: 'mean', label: 'Mean', desc: 'average of all past values' },
    { k: 'naive', label: 'Naive', desc: 'last value, carried forward' },
    { k: 'snaive', label: 'Seasonal naive', desc: 'same month last year' },
    { k: 'drift', label: 'Drift', desc: 'straight line from first to last point' },
  ] as const;

  let sid = $state('RSXFSN');
  let focus: string = $state('snaive');
  let h = $state(24);
  let originIdx = $state(0);
  let s: Series | null = $state(null);
  let el: HTMLDivElement;
  let minO = $state(0), maxO = $state(0);

  // Load a series and put the origin at December 2022 (the same split as the code lab below).
  async function load() {
    s = await loadSeries(sid, { start: '2005-01-01' });
    maxO = s.data.length - h - 1; minO = Math.max(36, s.data.length - 12 * 12);
    const dec22 = s.data.findIndex((p) => p.date.getFullYear() === 2022 && p.date.getMonth() === 11);
    originIdx = dec22 < 0 ? maxO : Math.min(maxO, Math.max(minO, dec22));
  }
  // Changing the horizon keeps the origin where it is (clamped so the test window still fits).
  function setHorizon() {
    if (!s) return;
    maxO = s.data.length - h - 1;
    if (originIdx > maxO) originIdx = maxO;
  }

  const result = $derived.by(() => {
    if (!s) return null;
    const o = Math.min(originIdx, s.data.length - h - 1);
    const train = s.data.slice(0, o + 1), test = s.data.slice(o + 1, o + 1 + h);
    const y = train.map((p) => p.value), act = test.map((p) => p.value);
    const m = s.freq === 12 ? 12 : s.freq === 4 ? 4 : 1;
    const f: Record<string, number[]> = { mean: fcMean(y, h), naive: fcNaive(y, h), snaive: fcSNaive(y, h, m), drift: fcDrift(y, h) };
    const acc = Object.fromEntries(Object.entries(f).map(([k, v]) => [k, accuracy(act, v, y, m)]));
    return { train, test, f, acc, dates: futureDates(train[train.length - 1].date, h, s.freq) };
  });

  const best = $derived.by(() => {
    if (!result) return {} as Record<string, string>;
    const out: Record<string, string> = {};
    for (const met of ['MAE', 'RMSE', 'MAPE', 'MASE'] as const) out[met] = Object.entries(result.acc).sort((a: any, b: any) => a[1][met] - b[1][met])[0][0];
    return out;
  });

  function draw() {
    if (!el || !result || !s) return;
    const { train, test, f, dates } = result;
    const show = train.slice(-Math.min(train.length, 72));
    const pal = C.s;
    const col: Record<string, string> = { mean: pal[4], naive: pal[1], snaive: pal[0], drift: pal[2] };
    const fcRows = METHODS.flatMap((m) => f[m.k].map((v, i) => ({ date: dates[i], value: v, k: m.k, label: m.label })));
    const errs = test.map((p, i) => ({ date: p.date, a: p.value, f: f[focus][i] }));
    const W = el.clientWidth;
    const chart = Plot.plot({
      width: W, height: Math.max(300, Math.min(420, W * 0.5)), marginLeft: 60, marginRight: 16, marginTop: 14,
      style: plotStyle(), x: { label: null }, y: { grid: true, nice: true, tickFormat: fmt, label: null },
      marks: [
        Plot.rectX([{ a: test[0]?.date, b: test[test.length - 1]?.date }], { x1: 'a', x2: 'b', fill: C.actual, fillOpacity: 0.05 }),
        Plot.text([test[0]?.date], { x: (d: any) => d, frameAnchor: 'top', dx: 6, dy: 2, textAnchor: 'start', text: () => 'Test period (hidden from the methods)', fill: C.muted, fontSize: 12, fontWeight: 700 }),
        Plot.text([show[0]?.date], { x: (d: any) => d, frameAnchor: 'top', dx: 2, dy: 2, textAnchor: 'start', text: () => 'Training data', fill: C.muted, fontSize: 12, fontWeight: 700 }),
        Plot.ruleX(errs, { x: 'date', y1: 'a', y2: 'f', stroke: C.danger, strokeOpacity: 0.55, strokeWidth: 2 }),
        Plot.lineY(show, { x: 'date', y: 'value', stroke: C.history, strokeWidth: 1.5 }),
        Plot.lineY(test, { x: 'date', y: 'value', stroke: C.actual, strokeWidth: 2.2, strokeDasharray: '5,3' }),
        Plot.lineY(fcRows.filter((r) => r.k !== focus), { x: 'date', y: 'value', z: 'k', stroke: (r: any) => col[r.k], strokeWidth: 1.2, strokeOpacity: 0.35 }),
        Plot.lineY(fcRows.filter((r) => r.k === focus), { x: 'date', y: 'value', stroke: col[focus], strokeWidth: 2.8 }),
        Plot.text(fcRows.filter((r) => r.k === focus), Plot.selectLast({ x: 'date', y: 'value', text: 'label', textAnchor: 'end', dy: -10, fill: col[focus], fontSize: 12, fontWeight: 700, stroke: 'var(--bg)', strokeWidth: 3, paintOrder: 'stroke' })),
        Plot.text(test, Plot.selectLast({ x: 'date', y: 'value', text: () => 'Actual', textAnchor: 'end', dy: 14, fill: C.actual, fontSize: 12, fontWeight: 700, stroke: 'var(--bg)', strokeWidth: 3, paintOrder: 'stroke' })),
        Plot.ruleX([show[show.length - 1].date], { stroke: C.borderStrong, strokeDasharray: '3,4' }),
        Plot.tip(errs, Plot.pointerX({ x: 'date', y: 'f', title: (r: any) => `${ym(r.date)}\nActual: ${fmt(r.a)}\nForecast: ${fmt(r.f)}\nError: ${fmt(r.a - r.f)}` })),
      ],
    });
    el.replaceChildren(chart);
  }

  $effect(() => { result; focus; draw(); });
  $effect(() => { sid; load(); });
  $effect(() => { h; setHorizon(); });
  onMount(() => watchLayout(el, draw));

  const unit = $derived(SERIES.find((x) => x.id === sid)!.unit);
  const pct = (v: number) => (isFinite(v) ? v.toFixed(1) + '%' : '—');
</script>

<Explorable title="Four benchmarks every forecast must beat" caption={`Drag the <b>forecast origin</b> to pretend you are standing at a different date. Each method only sees the data to the left. Red bars are the errors of the highlighted method. Data: FRED, ${unit}.`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Series">
      {#each SERIES as x}<button class:on={sid === x.id} onclick={() => (sid = x.id)}>{x.label}</button>{/each}
    </div>
    {#if s}
      <label class="sl">Forecast origin <input type="range" min={minO} max={maxO} bind:value={originIdx} aria-label="Forecast origin" /> <b>{ym(s.data[Math.min(originIdx, s.data.length - 1)].date)}</b></label>
    {/if}
    <label class="sl">Horizon <input type="range" min="6" max="36" step="6" bind:value={h} aria-label="Forecast horizon" /> <b>{h} mo</b></label>
  {/snippet}
  {#snippet aside()}
    {#if result}
      <div class="board">
        <div class="eyebrow">Test-period scorecard</div>
        <table>
          <thead><tr><th>Method</th><th title="Mean absolute error">MAE</th><th title="Mean absolute percentage error">MAPE</th><th title="Mean absolute scaled error">MASE</th></tr></thead>
          <tbody>
            {#each METHODS as m}
              <tr class:on={focus === m.k} onclick={() => (focus = m.k)} tabindex="0" onkeydown={(e) => e.key === 'Enter' && (focus = m.k)}>
                <td><span class="sw sw-{m.k}"></span>{m.label}</td>
                <td class:best={best.MAE === m.k}>{fmt(result.acc[m.k].MAE)}</td>
                <td class:best={best.MAPE === m.k}>{pct(result.acc[m.k].MAPE)}</td>
                <td class:best={best.MASE === m.k}>{isFinite(result.acc[m.k].MASE) ? result.acc[m.k].MASE.toFixed(2) : '—'}</td>
              </tr>
            {/each}
          </tbody>
        </table>
        <p class="verdict"><b>{METHODS.find((m) => m.k === best.MAE)?.label}</b> wins on MAE here. Its rule: <i>{METHODS.find((m) => m.k === best.MAE)?.desc}</i>.</p>
        <p class="hint">Click a row to highlight that method. Move the origin: does the winner change?</p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart" role="img" aria-label={result ? `${SERIES.find((x) => x.id === sid)!.label}: four benchmark forecasts from ${ym(result.train[result.train.length - 1].date)} compared with what actually happened. ${METHODS.find((m) => m.k === best.MAE)?.label} has the lowest MAE.` : 'Chart of benchmark forecasts versus actual data'}></div>
</Explorable>

<style>
  .chart { min-height: 300px; }
  .board { font-size: .82rem; }
  .board table { margin: .5rem 0 .8rem; font-size: .8rem; }
  .board th, .board td { padding: .38rem .35rem; }
  .board td { font-variant-numeric: tabular-nums; }
  .board tr { cursor: pointer; }
  .board tr.on { background: var(--surface-2); }
  .board tr.on td:first-child { color: var(--text); font-weight: 650; }
  .board td.best { color: var(--good); font-weight: 700; }
  .sw { display: inline-block; width: 10px; height: 3px; border-radius: 2px; margin-right: .45rem; vertical-align: middle; }
  .sw-snaive { background: var(--c-s1); } .sw-naive { background: var(--c-s2); } .sw-drift { background: var(--c-s3); } .sw-mean { background: var(--c-s5); }
  .verdict { color: var(--text-2); margin: 0 0 .5rem; }
  .hint { color: var(--muted); font-size: .76rem; margin: 0; }
</style>
