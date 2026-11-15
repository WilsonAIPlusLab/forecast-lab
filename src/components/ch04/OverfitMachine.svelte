<script lang="ts">
  // Overfitting machine: add polynomial trend terms; in-sample fit keeps improving while the 2019 test error explodes.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, ym, type Pt } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { ols } from './ols';

  const KMAX = 8;
  let deg = $state(1);
  let data: Pt[] = $state([]);
  let el: HTMLDivElement, elU: HTMLDivElement;

  onMount(() => {
    loadSeries('HOUSTNSA', { start: '2011-01-01', end: '2019-12-01' }).then((s) => (data = s.data));
    const redraw = () => draw();
    return watchLayout(el, redraw);
  });

  // Fit every degree once; the slider just picks one.
  const all = $derived.by(() => {
    if (!data.length) return null;
    const n = data.length, ntr = n - 12, c = (ntr - 1) / 2;
    return Array.from({ length: KMAX }, (_, k0) => {
      const k = k0 + 1;
      const row = (i: number) => { const t = (i - c) / c, r = [1]; for (let j = 1; j <= k; j++) r.push(t ** j); for (let m = 1; m < 12; m++) r.push(data[i].date.getMonth() === m ? 1 : 0); return r; };
      const f = ols(data.slice(0, ntr).map((_, i) => row(i)), data.slice(0, ntr).map((p) => p.value));
      const pred = data.map((_, i) => row(i).reduce((s, x, j) => s + x * f.beta[j], 0));
      const te = data.slice(ntr).map((p, i) => p.value - pred[ntr + i]);
      const tr = f.resid;
      return { k, pred, r2: f.r2, rmseTr: Math.sqrt(tr.reduce((s, e) => s + e * e, 0) / tr.length), rmseTe: Math.sqrt(te.reduce((s, e) => s + e * e, 0) / te.length), ntr, p: f.p };
    });
  });
  const cur = $derived(all ? all[deg - 1] : null);
  const best = $derived(all ? all.reduce((a, b) => (b.rmseTe < a.rmseTe ? b : a)) : null);

  function draw() {
    if (!el || !all || !cur) return;
    const W = el.clientWidth;
    const rows = data.map((p, i) => ({ date: p.date, a: p.value, f: cur.pred[i], test: i >= cur.ntr }));
    const lo = 20, hi = 160;
    const clip = rows.map((r) => ({ ...r, fc: Math.max(lo - 15, Math.min(hi + 15, r.f)) }));
    const off = rows.filter((r) => r.test && (r.f > hi || r.f < lo));
    const t0 = rows[cur.ntr].date, t1 = rows[rows.length - 1].date;
    const chart = Plot.plot({
      width: W, height: Math.max(260, Math.min(340, W * 0.42)), marginLeft: 44, marginRight: 16, marginTop: 18,
      style: plotStyle(), x: { label: null }, y: { grid: true, label: null, domain: [lo, hi], clamp: false },
      ariaLabel: `Housing starts with a degree-${cur.k} polynomial trend plus monthly dummies, fitted on 2011 to 2018 and extended into 2019`,
      marks: [
        Plot.rectX([{ a: t0, b: t1 }], { x1: 'a', x2: 'b', fill: C.actual, fillOpacity: 0.08 }),
        Plot.text([t0], { x: (d: any) => d, frameAnchor: 'top', dy: 4, dx: 6, textAnchor: 'start', text: () => 'Test year 2019', fill: C.text2, fontSize: 12 }),
        Plot.lineY(rows.filter((r) => !r.test), { x: 'date', y: 'a', stroke: C.history, strokeWidth: 1.6 }),
        Plot.lineY(rows.filter((r, i) => i >= cur.ntr - 1), { x: 'date', y: 'a', stroke: C.actual, strokeWidth: 2.2, strokeDasharray: '5 3' }),
        Plot.lineY(clip, { x: 'date', y: 'fc', stroke: C.fitted, strokeWidth: 2.4, clip: true }),
        off.length ? Plot.text([off[0]], { x: 'date', y: () => (off[0].f > hi ? hi - 8 : lo + 8), text: () => (off[0].f > hi ? 'Fit flies off the chart ↑' : 'Fit dives off the chart ↓'), dx: 6, textAnchor: 'start', fill: C.danger, fontSize: 12, fontWeight: 650, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }) : null,
        Plot.tip(rows, Plot.pointerX({ x: 'date', y: 'a', title: (r: any) => `${ym(r.date)}\nActual: ${r.a.toFixed(1)} thousand starts\nModel: ${r.f.toFixed(1)}${r.test ? ' (forecast)' : ' (fitted)'}` })),
      ],
    });
    el.replaceChildren(chart);
    if (elU) {
      const pts = all.flatMap((d) => [{ k: d.k, v: d.rmseTr, s: 'In-sample error (2011–18)' }, { k: d.k, v: Math.min(d.rmseTe, 60), raw: d.rmseTe, s: 'Test error (2019)' }]);
      const u = Plot.plot({
        width: W, height: 220, marginLeft: 44, marginRight: 170, marginTop: 16, marginBottom: 36,
        style: plotStyle(), x: { label: 'Polynomial degree of the trend →', ticks: KMAX, tickFormat: 'd', labelAnchor: 'right' },
        y: { grid: true, label: 'RMSE, thousand starts', labelAnchor: 'top', domain: [0, 60] },
        ariaLabel: 'Root mean squared error by polynomial degree: in-sample error falls steadily, test error is U-shaped',
        marks: [
          Plot.ruleX([deg], { stroke: C.borderStrong, strokeDasharray: '3 4' }),
          Plot.lineY(pts, { x: 'k', y: 'v', z: 's', stroke: (d: any) => (d.s.startsWith('Test') ? C.actual : C.fitted), strokeWidth: 2.4 }),
          Plot.dot(pts, { x: 'k', y: 'v', fill: (d: any) => (d.s.startsWith('Test') ? C.actual : C.fitted), r: (d: any) => (d.k === deg ? 6 : 3.5), stroke: C.surface, strokeWidth: 1.5 }),
          Plot.text(pts, Plot.selectLast({ x: 'k', y: 'v', z: 's', text: 's', dx: 10, textAnchor: 'start', fill: (d: any) => (d.s.startsWith('Test') ? C.actual : C.fitted), fontSize: 12, fontWeight: 650 })),
          Plot.text(pts.filter((d: any) => d.raw > 60), { x: 'k', y: 'v', text: (d: any) => '↑ ' + Math.round(d.raw), dy: -12, fill: C.danger, fontSize: 12 }),
          Plot.tip(pts, Plot.pointer({ x: 'k', y: 'v', title: (d: any) => `Degree ${d.k}\n${d.s}: ${(d.raw ?? d.v).toFixed(1)} thousand starts (RMSE)` })),
        ],
      });
      elU.replaceChildren(u);
    }
  }
  $effect(() => { cur; draw(); });
</script>

<Explorable title="The overfitting machine: better fit, worse forecast"
  caption="Housing starts (thousands of units, <b>not</b> seasonally adjusted), modeled with 11 monthly dummies plus a polynomial time trend: degree 1 is a straight line, degree 2 a parabola, and so on. The model is fitted on 2011–2018 and must forecast 2019 (gold, dashed). Raise the degree: the in-sample error never rises, but the test error bottoms out at degree 2 and then, apart from one small dip, climbs steeply. Test errors above 60 are drawn at the top edge with their true value. Data: FRED (HOUSTNSA).">
  {#snippet controls()}
    <label class="sl">Trend degree <input type="range" min="1" max={KMAX} step="1" bind:value={deg} aria-label="Polynomial degree of the trend" aria-valuetext={`degree ${deg}`} /> <b>{deg}</b></label>
  {/snippet}
  {#snippet aside()}
    {#if cur && best}
      <div class="om">
        <div class="stat"><span class="stat-v">{cur.r2.toFixed(3)}</span><span class="stat-l"><b>In-sample R²</b> (2011–2018)</span></div>
        <div class="stat"><span class="stat-v">{cur.rmseTr.toFixed(1)}k</span><span class="stat-l"><b>In-sample RMSE</b>, thousand starts</span></div>
        <div class="stat"><span class="stat-v" class:bad={cur.rmseTe > 2 * best.rmseTe}>{cur.rmseTe.toFixed(1)}k</span><span class="stat-l"><b>Test RMSE</b> on 2019, thousand starts</span></div>
        <p class="v" aria-live="polite">
          {#if cur.k === best.k}This is the sweet spot: <b>{cur.p}</b> coefficients, lowest test error.
          {:else if cur.k < best.k}Too simple: the straight trend misses the curve in the data.
          {:else}Overfit: {cur.p} coefficients chase noise, and the curve bends wildly once it leaves the data.{/if}
        </p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart"></div>
  <div bind:this={elU}></div>
</Explorable>

<style>
  .chart { min-height: 260px; }
  .om { display: grid; gap: .8rem; }
  .bad { color: var(--danger) !important; }
  .v { margin: 0; font-size: .82rem; color: var(--text-2); line-height: 1.45; }
</style>
