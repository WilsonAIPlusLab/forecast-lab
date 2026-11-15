<script lang="ts">
  // Scenario dashboard: set where gas, unemployment and mortgage rates go; a fitted regression turns that into a
  // 12-month vehicle-sales forecast, with and without uncertainty about the drivers themselves.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, futureDates, rng, ym } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { ols, predict, predSE, joinMonthly, t975, type OLS } from './ols';

  const H = 12, NSIM = 5000;
  let rows: { date: Date; v: number[] }[] = $state([]);
  let fit: OLS | null = $state(null);
  let now = $state({ gas: 4.3, un: 4.1, mr: 7.3 });
  let gasT = $state(4.3), unT = $state(4.1), mrT = $state(7.3);
  let el: HTMLDivElement;

  onMount(() => {
    (async () => {
      const [veh, gas, un, mr] = await Promise.all([
        loadSeries('TOTALSA'), loadSeries('GASREGW', { to: 'month' }), loadSeries('UNRATE'), loadSeries('MORTGAGE30US', { to: 'month' }),
      ]);
      rows = joinMonthly([veh.data, gas.data, un.data, mr.data]).filter((r) => r.date.getFullYear() >= 1993);
      const X = rows.map((r) => [1, r.v[1], r.v[2], r.v[3], [2021, 2022].includes(r.date.getFullYear()) ? 1 : 0]);
      fit = ols(X, rows.map((r) => r.v[0]));
      const last = rows[rows.length - 1].v;
      now = { gas: last[1], un: last[2], mr: last[3] };
      gasT = +last[1].toFixed(2); unT = last[2]; mrT = +last[3].toFixed(2);
    })();
    return watchLayout(el, draw);
  });

  const ramp = (a: number, b: number) => Array.from({ length: H }, (_, i) => (i < 3 ? a + ((b - a) * (i + 1)) / 3 : b));
  const line = (a: number, b: number) => Array.from({ length: H }, (_, i) => a + ((b - a) * i) / (H - 1));
  // Historical month-to-month changes in the three drivers (kept together, so their co-movement is preserved).
  const shocks = $derived(rows.slice(1).map((r, i) => [r.v[1] - rows[i].v[1], r.v[2] - rows[i].v[2], r.v[3] - rows[i].v[3]])
    .filter((s, i) => rows[i + 1].date.getMonth() - rows[i].date.getMonth() === 1 || rows[i + 1].date.getMonth() - rows[i].date.getMonth() === -11));

  function scenario(g: number, u: number, m: number) {
    const gp = ramp(now.gas, g), up = line(now.un, u), mp = ramp(now.mr, m);
    return gp.map((_, i) => [1, gp[i], up[i], mp[i], 0]);
  }

  const out = $derived.by(() => {
    if (!fit || !rows.length) return null;
    const f = fit;
    const X = scenario(gasT, unT, mrT), Xb = scenario(now.gas, now.un, now.mr);
    const tq = t975(f.n - f.p);
    const mean = X.map((x) => predict(f.beta, x)), base = Xb.map((x) => predict(f.beta, x));
    const lo = X.map((x, i) => mean[i] - tq * predSE(f, x)), hi = X.map((x, i) => mean[i] + tq * predSE(f, x));
    // Simulate: scenario path + bootstrapped driver surprises (cumulated) + regression noise.
    const R = rng(7), sims: number[][] = Array.from({ length: H }, () => []);
    for (let s = 0; s < NSIM; s++) {
      let dg = 0, du = 0, dm = 0;
      for (let h = 0; h < H; h++) {
        const sh = shocks[Math.floor(R.u() * shocks.length)];
        dg += sh[0]; du += sh[1]; dm += sh[2];
        const x = [1, X[h][1] + dg, Math.max(2.5, X[h][2] + du), Math.max(0, X[h][3] + dm), 0];
        sims[h].push(predict(f.beta, x) + f.sigma * R.norm());
      }
    }
    const q = (a: number[], p: number) => { const b = a.slice().sort((x, y) => x - y); return b[Math.floor(p * (b.length - 1))]; };
    const lo2 = sims.map((a) => q(a, 0.025)), hi2 = sims.map((a) => q(a, 0.975));
    const avg = (a: number[]) => a.reduce((s, v) => s + v, 0) / a.length;
    const contrib = [1, 2, 3].map((j) => f.beta[j] * avg(X.map((x, i) => x[j] - Xb[i][j])));
    const dates = futureDates(rows[rows.length - 1].date, H, 12);
    return { mean, base, lo, hi, lo2, hi2, dates, avg: avg(mean), avgBase: avg(base), contrib, width1: hi[H - 1] - lo[H - 1], width2: hi2[H - 1] - lo2[H - 1] };
  });

  function draw() {
    if (!el || !out) return;
    const W = el.clientWidth;
    const hist = rows.filter((r) => r.date.getFullYear() >= 2019).map((r) => ({ date: r.date, y: r.v[0] }));
    const fc = out.dates.map((d, i) => ({ date: d, m: out.mean[i], b: out.base[i], lo: out.lo[i], hi: out.hi[i], lo2: out.lo2[i], hi2: out.hi2[i] }));
    const join = { date: hist[hist.length - 1].date, m: hist[hist.length - 1].y };
    const lastF = fc[fc.length - 1];
    const chart = Plot.plot({
      width: W, height: Math.max(300, Math.min(400, W * 0.5)), marginLeft: 44, marginRight: 150, marginTop: 14,
      style: plotStyle(), x: { label: null }, y: { grid: true, label: null, domain: [6, 22], tickFormat: (v: number) => v + ' mn' },
      ariaLabel: 'Vehicle sales history since 2019 and a 12-month scenario forecast with two 95% bands',
      marks: [
        Plot.areaY(fc, { x: 'date', y1: 'lo2', y2: 'hi2', fill: C.forecast, fillOpacity: 0.13 }),
        Plot.areaY(fc, { x: 'date', y1: 'lo', y2: 'hi', fill: C.forecast, fillOpacity: 0.3 }),
        Plot.lineY(hist, { x: 'date', y: 'y', stroke: C.history, strokeWidth: 2 }),
        Plot.lineY(fc, { x: 'date', y: 'b', stroke: C.muted, strokeWidth: 1.5, strokeDasharray: '4 4' }),
        Plot.lineY([join, ...fc], { x: 'date', y: 'm', stroke: C.forecast, strokeWidth: 3 }),
        Plot.ruleX([join.date], { stroke: C.borderStrong, strokeDasharray: '3 4' }),
        Plot.text([join], { x: 'date', y: () => 21.4, text: () => 'Forecast starts', textAnchor: 'end', dx: -6, fill: C.muted, fontSize: 12 }),
        Plot.text([lastF], { x: 'date', y: 'm', text: (d: any) => `Scenario ${d.m.toFixed(1)} mn`, dx: 8, textAnchor: 'start', fill: C.forecast, fontSize: 12, fontWeight: 700 }),
        Plot.text([lastF], { x: 'date', y: 'hi', text: () => '95%, drivers known', dx: 8, dy: 8, textAnchor: 'start', fill: C.text2, fontSize: 12 }),
        Plot.text([lastF], { x: 'date', y: 'hi2', text: () => '95%, drivers uncertain', dx: 8, dy: -8, textAnchor: 'start', fill: C.muted, fontSize: 12 }),
        Plot.text([lastF], { x: 'date', y: 'b', text: () => 'Baseline', dx: 8, dy: Math.abs(lastF.b - lastF.m) < 0.5 ? 14 : 0, textAnchor: 'start', fill: C.muted, fontSize: 12 }),
        Plot.tip(fc, Plot.pointerX({ x: 'date', y: 'm', title: (r: any) => `${ym(r.date)}\nScenario: ${r.m.toFixed(2)} mn units (SAAR)\nBaseline: ${r.b.toFixed(2)} mn\n95%, drivers known: ${r.lo.toFixed(1)}–${r.hi.toFixed(1)}\n95%, drivers uncertain: ${r.lo2.toFixed(1)}–${r.hi2.toFixed(1)}` })),
        Plot.tip(hist, Plot.pointerX({ x: 'date', y: 'y', title: (r: any) => `${ym(r.date)}\nActual sales: ${r.y.toFixed(2)} mn units (SAAR)` })),
      ],
    });
    el.replaceChildren(chart);
  }
  $effect(() => { out; draw(); });

  function preset(k: string) {
    if (k === 'today') { gasT = +now.gas.toFixed(2); unT = now.un; mrT = +now.mr.toFixed(2); }
    if (k === 'gas5') { gasT = 5; unT = now.un; mrT = +now.mr.toFixed(2); }
    if (k === 'squeeze') { gasT = 5; unT = 5.5; mrT = 8; }
    if (k === 'relief') { gasT = 3; unT = now.un; mrT = 5.5; }
  }
  const sgn = (v: number) => (v >= 0 ? '+' : '−') + Math.abs(v).toFixed(2);
  const NAMES = ['Gas price', 'Unemployment', 'Mortgage rate'];
</script>

<Explorable title="What if gas hits $5? Set the drivers, read the forecast"
  caption="A regression of light vehicle sales (millions of units, seasonally adjusted annual rate) on the gas price, the unemployment rate, the 30-year mortgage rate and a 2021–22 chip-shortage dummy, fitted on 1993 to the latest month. Gas and mortgage rates move to your target over three months; unemployment drifts there over the year. The <b>dark band</b> assumes your driver path comes true exactly. The <b>light band</b> also lets the drivers wander, by replaying 5,000 random sequences of real historical month-to-month moves. Data: FRED (TOTALSA, GASREGW, UNRATE, MORTGAGE30US).">
  {#snippet controls()}
    <label class="sl">Gas, $/gal <input type="range" min="2.5" max="6.5" step="0.05" bind:value={gasT} aria-label="Gas price target" aria-valuetext={`$${(+gasT).toFixed(2)} per gallon`} /> <b>${(+gasT).toFixed(2)}</b></label>
    <label class="sl">Unemployment <input type="range" min="3" max="10" step="0.1" bind:value={unT} aria-label="Unemployment rate target" aria-valuetext={`${(+unT).toFixed(1)} percent`} /> <b>{(+unT).toFixed(1)}%</b></label>
    <label class="sl">Mortgage rate <input type="range" min="3" max="9.5" step="0.05" bind:value={mrT} aria-label="Mortgage rate target" aria-valuetext={`${(+mrT).toFixed(2)} percent`} /> <b>{(+mrT).toFixed(2)}%</b></label>
  {/snippet}
  {#snippet aside()}
    {#if out}
      <div class="sd">
        <div class="stat"><span class="stat-v">{out.avg.toFixed(2)} mn</span><span class="stat-l">Average forecast, next 12 months (baseline {out.avgBase.toFixed(2)} mn)</span></div>
        <div class="bridge" aria-label="Contribution of each driver to the gap from baseline">
          <div class="bh">Gap from baseline, by driver</div>
          {#each out.contrib as c, j}
            <div class="br"><span class="bn">{NAMES[j]}</span><span class="bt"><i class:neg={c < 0} style={`width:${Math.min(100, Math.abs(c) * 40)}%`}></i></span><span class="bv">{sgn(c)}</span></div>
          {/each}
          <div class="br tot"><span class="bn">Total</span><span class="bt"></span><span class="bv">{sgn(out.avg - out.avgBase)}</span></div>
        </div>
        <p class="unc">Band width after 12 months: <b>{out.width1.toFixed(1)} mn</b> if the drivers are known, <b>{out.width2.toFixed(1)} mn</b> once they can surprise you.</p>
        <div class="presets"><span>Try:</span>
          <button onclick={() => preset('gas5')}>Gas hits $5</button>
          <button onclick={() => preset('squeeze')}>Squeeze</button>
          <button onclick={() => preset('relief')}>Relief</button>
          <button onclick={() => preset('today')}>Today</button>
        </div>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 300px; }
  .sd { display: grid; gap: .9rem; font-size: .82rem; }
  .bh { font-weight: 650; color: var(--text-2); margin-bottom: .35rem; }
  .br { display: grid; grid-template-columns: 6.6rem 1fr 3.4rem; gap: .5rem; align-items: center; padding: .16rem 0; }
  .bn { color: var(--text-2); }
  .bt { height: 9px; background: var(--surface-2); border-radius: 3px; overflow: hidden; }
  .bt i { display: block; height: 100%; background: var(--good); border-radius: 3px; }
  .bt i.neg { background: var(--danger); }
  .bv { font: 600 .8rem var(--font-ui); font-variant-numeric: tabular-nums; text-align: right; color: var(--text); }
  .tot { border-top: 1px solid var(--border); margin-top: .2rem; padding-top: .35rem; }
  .tot .bt { background: none; }
  .unc { margin: 0; color: var(--text-2); line-height: 1.45; }
  .presets { display: flex; flex-wrap: wrap; gap: .35rem; align-items: center; }
  .presets span { color: var(--muted); font-size: .76rem; }
  .presets button { all: unset; cursor: pointer; font: 600 .74rem var(--font-ui); padding: .25rem .55rem; border-radius: 7px; border: 1px solid var(--border-strong); color: var(--text-2); }
  .presets button:hover { color: var(--text); border-color: var(--accent); }
  .presets button:focus-visible { outline: 2px solid var(--accent-2); }
</style>
