<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, ym } from '../../lib/ts';
  import { C, plotStyle, fmt, watchLayout } from '../../lib/viz/theme';
  import { fitETS, forecast } from './models';

  // Forecast combination: blend exponential smoothing with seasonal naive and watch the test error.
  const SERIES = [
    { id: 'MRTSSM442USN', label: 'Furniture' },
    { id: 'MRTSSM446USN', label: 'Health & personal care' },
    { id: 'MRTSSM451USN', label: 'Sporting goods' },
    { id: 'RSXFSN', label: 'Total retail' },
  ];
  let sid = $state('MRTSSM442USN');
  let w = $state(0.5);
  let base: { dates: Date[]; act: number[]; A: number[]; B: number[]; hist: { date: Date; value: number }[] } | null = $state.raw(null);
  let el: HTMLDivElement, el2: HTMLDivElement;

  async function load() {
    const s = await loadSeries(sid, { start: '2010-01-01', end: '2019-12-01' });
    const tr = s.data.filter((p) => p.date.getFullYear() < 2018), te = s.data.filter((p) => p.date.getFullYear() >= 2018);
    const y = tr.map((p) => p.value);
    const fit = fitETS(y.map(Math.log), { m: 12, trend: true, season: true });
    base = { dates: te.map((p) => p.date), act: te.map((p) => p.value), A: forecast(fit, te.length).map(Math.exp), B: te.map((_, i) => y[y.length - 12 + (i % 12)]), hist: tr.slice(-24) };
  }
  const mae = (b: NonNullable<typeof base>, v: number) => b.act.reduce((s, a, i) => s + Math.abs(a - (v * b.A[i] + (1 - v) * b.B[i])), 0) / b.act.length;
  const res = $derived.by(() => {
    if (!base) return null;
    const curve = Array.from({ length: 41 }, (_, i) => ({ w: i / 40, mae: mae(base!, i / 40) }));
    const eA = base.act.map((a, i) => a - base!.A[i]), eB = base.act.map((a, i) => a - base!.B[i]);
    const m = (x: number[]) => x.reduce((a, b) => a + b, 0) / x.length;
    const ma = m(eA), mb = m(eB);
    const cov = m(eA.map((x, i) => (x - ma) * (eB[i] - mb)));
    const corr = cov / Math.sqrt(m(eA.map((x) => (x - ma) ** 2)) * m(eB.map((x) => (x - mb) ** 2)));
    const best = curve.reduce((a, b) => (b.mae < a.mae ? b : a));
    return { curve, best, now: mae(base, w), a: mae(base, 1), b: mae(base, 0), half: mae(base, 0.5), corr, ma, mb };
  });

  function draw() {
    if (!el || !res || !base) return;
    const W = el.clientWidth;
    el.replaceChildren(Plot.plot({
      width: W, height: 230, marginLeft: 56, marginRight: 20, marginTop: 18, style: plotStyle(),
      x: { label: 'Weight on exponential smoothing →', domain: [0, 1], tickFormat: (d: number) => `${Math.round(d * 100)}%` },
      y: { grid: true, label: '↑ Test MAE, 2018–2019 ($ millions)', zero: false, tickFormat: fmt },
      marks: [
        Plot.lineY(res.curve, { x: 'w', y: 'mae', stroke: C.s[0], strokeWidth: 2.4 }),
        Plot.dot([{ w: 0, mae: res.b }, { w: 1, mae: res.a }], { x: 'w', y: 'mae', r: 5, fill: C.surface, stroke: C.muted, strokeWidth: 2 }),
        Plot.text([{ w: 0, mae: res.b }], { x: 'w', y: 'mae', text: () => 'Seasonal naive only', dy: -12, textAnchor: 'start', fill: C.text2, fontSize: 12 }),
        Plot.text([{ w: 1, mae: res.a }], { x: 'w', y: 'mae', text: () => 'Smoothing only', dy: -12, textAnchor: 'end', fill: C.text2, fontSize: 12 }),
        Plot.ruleX([w], { stroke: C.forecast, strokeDasharray: '3,3' }),
        Plot.dot([{ w, mae: res.now }], { x: 'w', y: 'mae', r: 6.5, fill: C.forecast, stroke: C.surface, strokeWidth: 1.5 }),
        Plot.tip(res.curve, Plot.pointerX({ x: 'w', y: 'mae', title: (r: any) => `${Math.round(r.w * 100)}% smoothing, ${Math.round((1 - r.w) * 100)}% seasonal naive\nMAE: ${fmt(r.mae)} $ millions` })),
      ],
    }));
    const rows = base.dates.map((d, i) => ({ date: d, A: base!.A[i], B: base!.B[i], X: w * base!.A[i] + (1 - w) * base!.B[i], act: base!.act[i] }));
    const long = [...rows.map((r) => ({ date: r.date, v: r.A, k: 'Smoothing' })), ...rows.map((r) => ({ date: r.date, v: r.B, k: 'Seasonal naive' }))];
    el2.replaceChildren(Plot.plot({
      width: W, height: 220, marginLeft: 56, marginRight: 100, marginTop: 10, style: plotStyle(),
      x: { label: null }, y: { grid: true, label: '↑ Sales ($ millions)', tickFormat: fmt },
      marks: [
        Plot.lineY(base.hist, { x: 'date', y: 'value', stroke: C.history, strokeWidth: 1.6 }),
        Plot.lineY(long, { x: 'date', y: 'v', z: 'k', stroke: C.muted, strokeOpacity: 0.45, strokeWidth: 1.25 }),
        Plot.lineY(rows, { x: 'date', y: 'act', stroke: C.actual, strokeWidth: 2.2, strokeDasharray: '5,3' }),
        Plot.lineY(rows, { x: 'date', y: 'X', stroke: C.forecast, strokeWidth: 2.6 }),
        Plot.text(rows.slice(-1), { x: 'date', y: 'X', text: () => 'Blend', dx: 6, textAnchor: 'start', fill: C.text, fontSize: 12, fontWeight: 600 }),
        Plot.text(rows.slice(-1), { x: 'date', y: 'act', text: () => 'Actual', dx: 6, dy: 12, textAnchor: 'start', fill: C.text2, fontSize: 12 }),
        Plot.tip(rows, Plot.pointerX({ x: 'date', y: 'X', title: (r: any) => `${ym(r.date)}\nActual: ${fmt(r.act)}\nBlend: ${fmt(r.X)}\nSmoothing: ${fmt(r.A)} · Seasonal naive: ${fmt(r.B)} ($ millions)` })),
      ],
    }));
  }

  $effect(() => { sid; load(); });
  $effect(() => { res; w; draw(); });
  onMount(() => watchLayout(el, draw));
</script>

<Explorable title="Blending two forecasts: when does the mix beat both?"
  caption="Two forecasts of 2018–2019 made at the end of 2017 from 2010–2017 data: exponential smoothing on log sales (trend + seasonality) and seasonal naive. Drag the weight to blend them month by month. The top chart shows test-period MAE for every weight. Grey lines below are the two ingredients; violet is your blend; gold dashed is what happened. Retail sales by store type, $ millions, NSA (FRED).">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Series">
      {#each SERIES as x}<button class:on={sid === x.id} onclick={() => (sid = x.id)}>{x.label}</button>{/each}
    </div>
    <label class="sl">Weight on smoothing <input type="range" min="0" max="1" step="0.025" bind:value={w} aria-valuetext={`${Math.round(w * 100)} percent`} /> <b>{Math.round(w * 100)}%</b></label>
  {/snippet}
  {#snippet aside()}
    {#if res}
      <div class="ro" aria-live="polite">
        <table>
          <tbody>
            <tr><td>Smoothing only</td><td>{fmt(res.a)}</td></tr>
            <tr><td>Seasonal naive only</td><td>{fmt(res.b)}</td></tr>
            <tr><td>50/50 average</td><td class:good={res.half < Math.min(res.a, res.b)}>{fmt(res.half)}</td></tr>
            <tr class="on"><td>Your blend ({Math.round(w * 100)}%)</td><td class:good={res.now < Math.min(res.a, res.b)}>{fmt(res.now)}</td></tr>
          </tbody>
        </table>
        <p>MAE in $ millions. Best weight here: <b>{Math.round(res.best.w * 100)}%</b> on smoothing.</p>
        <p>Average miss: smoothing <b>{fmt(Math.abs(res.ma))} too {res.ma < 0 ? 'high' : 'low'}</b>, seasonal naive <b>{fmt(Math.abs(res.mb))} too {res.mb < 0 ? 'high' : 'low'}</b>. {Math.sign(res.ma) !== Math.sign(res.mb) ? 'They err in opposite directions, so blending cancels part of each bias.' : 'They err in the same direction, so blending cannot cancel the bias.'} Correlation of their month-to-month errors: {res.corr.toFixed(2)}.</p>
        <p class="hint">The best weight is only known after the fact. The 50/50 average needs no hindsight.</p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} role="img" aria-label="Test error as a function of the blending weight"></div>
  <div bind:this={el2} role="img" aria-label="Blended forecast against actual sales in 2018 and 2019"></div>
</Explorable>

<style>
  .ro { font-size: .84rem; color: var(--text-2); display: grid; gap: .5rem; }
  .ro p { margin: 0; }
  .ro table { margin: 0; font-size: .8rem; }
  .ro td { padding: .3rem .35rem; font-variant-numeric: tabular-nums; }
  .ro td:last-child { text-align: right; }
  .ro tr.on td { color: var(--text); font-weight: 650; }
  .ro td.good { color: var(--good); font-weight: 700; }
  .ro b { color: var(--text); }
  .hint { color: var(--muted); font-size: .78rem; }
</style>
