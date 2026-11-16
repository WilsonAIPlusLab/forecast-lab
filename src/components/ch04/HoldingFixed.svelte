<script lang="ts">
  // "Holding the other drivers fixed", made literal: an added-variable (Frisch–Waugh) plot of car sales against the
  // mortgage rate. Tick a driver to hold it fixed; the cloud re-forms and the slope (with its 95% interval) updates.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, ym } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { ols, t975 } from './ols';
  import { carRows, neweyWest, partialOut, type CarRow } from './interp';

  let rows: CarRow[] = $state([]);
  let holdUn = $state(false), holdGas = $state(false), holdChip = $state(false);
  let seType: 'ols' | 'nw' = $state('ols');
  let el: HTMLDivElement;
  let shown: { x: number; y: number }[] = [];   // positions currently drawn (for the tween)
  let raf = 0;

  onMount(() => {
    (async () => {
      const [veh, gas, un, mr] = await Promise.all([
        loadSeries('TOTALSA'), loadSeries('GASREGW', { to: 'month' }), loadSeries('UNRATE'), loadSeries('MORTGAGE30US', { to: 'month' }),
      ]);
      rows = carRows(veh.data, gas.data, un.data, mr.data);
    })();
    const stop = watchLayout(el, () => draw(shown));
    return () => { stop(); cancelAnimationFrame(raf); };
  });

  const era = (d: Date) => (d.getFullYear() < 2008 ? '1993–2007' : d.getFullYear() < 2020 ? '2008–2019' : '2020–2026');
  const ERAS = ['1993–2007', '2008–2019', '2020–2026'];
  const mean = (a: number[]) => a.reduce((s, v) => s + v, 0) / a.length;
  const corr = (a: number[], b: number[]) => { const ma = mean(a), mb = mean(b); let sab = 0, saa = 0, sbb = 0; a.forEach((v, i) => { sab += (v - ma) * (b[i] - mb); saa += (v - ma) ** 2; sbb += (b[i] - mb) ** 2; }); return sab / Math.sqrt(saa * sbb); };

  const model = $derived.by(() => {
    if (!rows.length) return null;
    const y = rows.map((r) => r.veh), x = rows.map((r) => r.mr);
    const ctl: number[][] = [], names: string[] = [];
    if (holdUn) { ctl.push(rows.map((r) => r.un)); names.push('unemployment rate'); }
    if (holdGas) { ctl.push(rows.map((r) => r.gas)); names.push('gas price'); }
    if (holdChip) { ctl.push(rows.map((r) => r.chip)); names.push('chip-shortage status'); }
    const X = rows.map((_, i) => [1, x[i], ...ctl.map((c) => c[i])]);
    const f = ols(X, y);
    const seOLS = f.sigma * Math.sqrt(f.XtXinv[1][1]);
    const seNW = Math.sqrt(neweyWest(X, f, 12)[1][1]);
    const se = seType === 'ols' ? seOLS : seNW, tq = t975(f.n - f.p);
    const xm = mean(x), ym_ = mean(y);
    const xa = ctl.length ? partialOut(x, ctl).map((v) => v + xm) : x;
    const ya = ctl.length ? partialOut(y, ctl).map((v) => v + ym_) : y;
    return { b: f.beta[1], se, seOLS, seNW, lo: f.beta[1] - tq * se, hi: f.beta[1] + tq * se, xa, ya, xm, ym: ym_, names, r2: f.r2,
      rUn: corr(x, rows.map((r) => r.un)), rGas: corr(x, rows.map((r) => r.gas)) };
  });

  // Tween the dots from where they are to where the new model puts them (skipped under reduced motion).
  $effect(() => {
    if (!model) return;
    const target = model.xa.map((v, i) => ({ x: v, y: model.ya[i] }));
    const from = shown.length === target.length ? shown.slice() : target;
    const reduce = typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    cancelAnimationFrame(raf);
    if (reduce || from === target) { shown = target; draw(target); return; }
    const t0 = performance.now(), D = 420;
    const step = (now: number) => {
      const u = Math.min(1, (now - t0) / D), e = u < 0.5 ? 2 * u * u : 1 - (-2 * u + 2) ** 2 / 2;
      shown = target.map((p, i) => ({ x: from[i].x + (p.x - from[i].x) * e, y: from[i].y + (p.y - from[i].y) * e }));
      draw(shown);
      if (u < 1) raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
  });

  function draw(pos: { x: number; y: number }[]) {
    if (!el || !model || !pos.length) return;
    const W = el.clientWidth, m = model;
    const pts = pos.map((p, i) => ({ ...p, date: rows[i].date, era: era(rows[i].date), mr: rows[i].mr, veh: rows[i].veh }));
    const cols = C.s;
    const line = [2.2, 9.5].map((xv) => ({ x: xv, y: m.ym + m.b * (xv - m.xm) }));
    const chart = Plot.plot({
      width: W, height: Math.max(290, Math.min(380, W * 0.5)), marginLeft: 50, marginRight: 18, marginTop: 14, marginBottom: 40,
      style: plotStyle(),
      x: { label: m.names.length ? 'Mortgage rate, adjusted (%) →' : 'Mortgage rate (%) →', domain: [2.2, 9.5] },
      y: { grid: true, label: null, domain: [6, 23], tickFormat: (v: number) => v + ' mn' },
      color: { domain: ERAS, range: cols.slice(0, 3) },
      ariaLabel: `Scatter of monthly vehicle sales against the mortgage rate${m.names.length ? ', holding ' + listJoin(m.names) + ' fixed' : ''}, with the least-squares line`,
      marks: [
        Plot.dot(pts, { x: 'x', y: 'y', fill: 'era', r: 2.6, fillOpacity: 0.65, clip: true }),
        Plot.line(line, { x: 'x', y: 'y', stroke: C.text, strokeWidth: 3 }),
        Plot.text([line[1]], { x: 'x', y: 'y', text: () => `slope ${m.b >= 0 ? '+' : '−'}${Math.abs(m.b).toFixed(3)}`, dy: m.b >= 0 ? -12 : 14, textAnchor: 'end', fill: C.text, fontWeight: 700, fontSize: 12, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
        Plot.tip(pts, Plot.pointer({ x: 'x', y: 'y', title: (d: any) => `${ym(d.date)}\nSales: ${d.veh.toFixed(1)} mn (SAAR)\nMortgage rate: ${d.mr.toFixed(2)}%${m.names.length ? `\nAdjusted: ${d.x.toFixed(2)}%, ${d.y.toFixed(1)} mn` : ''}` })),
      ],
    });
    el.replaceChildren(chart);
  }
  // position (in %) of a coefficient value on the small interval bar, which spans -0.75 to +0.35
  const pcCI = (v: number) => `${(100 * (Math.max(-0.75, Math.min(0.35, v)) + 0.75)) / 1.1}%`;
  // "a", "a and b", "a, b and c"
  const listJoin = (a: string[]) => (a.length < 2 ? a.join('') : a.slice(0, -1).join(', ') + ' and ' + a[a.length - 1]);
  const k = (v: number) => Math.round(Math.abs(v) * 1000) * 1000;   // millions → cars, rounded to 1,000
</script>

<Explorable title="Hold a driver fixed and watch the mortgage-rate slope flip"
  caption="Each dot is one month, 1993 to the latest month: U.S. light vehicle sales (millions, seasonally adjusted annual rate) against the 30-year mortgage rate. With nothing held fixed, the line slopes slightly <b>up</b>. Tick <b>Unemployment</b>: the chart removes the part of sales and of the mortgage rate that unemployment explains and plots what is left (re-centered on the averages). The slope of that cloud is exactly the multiple-regression coefficient. Then switch to <b>Newey–West</b> standard errors (12-month window, as in the Python lab) to see the honest interval. <b>Takeaway:</b> a coefficient answers “compared with months that had the same values of the other drivers”, so it changes when the list of drivers changes. Data: FRED (TOTALSA, MORTGAGE30US, UNRATE, GASREGW).">
  {#snippet controls()}
    <div class="terms" role="group" aria-label="Drivers to hold fixed">
      <span>Hold fixed:</span>
      <label><input type="checkbox" bind:checked={holdUn} /> Unemployment</label>
      <label><input type="checkbox" bind:checked={holdGas} /> Gas price</label>
      <label><input type="checkbox" bind:checked={holdChip} /> Chip shortage</label>
    </div>
    <div class="grp"><span class="lab" id="hf-se">Standard errors</span>
      <div class="seg" role="group" aria-labelledby="hf-se">
        <button class:on={seType === 'ols'} aria-pressed={seType === 'ols'} onclick={() => (seType = 'ols')}>Textbook OLS</button>
        <button class:on={seType === 'nw'} aria-pressed={seType === 'nw'} onclick={() => (seType = 'nw')}>Newey–West</button>
      </div></div>
  {/snippet}
  {#snippet aside()}
    {#if model}
      <div class="hf">
        <div class="legend" aria-hidden="true">
          {#each ERAS as e, i}<span><i style={`background:${['var(--c-s1)', 'var(--c-s2)', 'var(--c-s3)'][i]}`}></i>{e}</span>{/each}
        </div>
        <div class="stat"><span class="stat-v">b = {model.b >= 0 ? '+' : '−'}{Math.abs(model.b).toFixed(3)}</span><span class="stat-l">Mortgage-rate coefficient (million cars per percentage point)</span></div>
        <p class="words">
          {#if model.names.length}Comparing months with the same {listJoin(model.names)}, {:else}Comparing all months, with nothing held fixed, {/if}
          a mortgage rate one point higher went with about <b>{k(model.b).toLocaleString()} {model.b < 0 ? 'fewer' : 'more'}</b> cars a year.
        </p>
        <div class="ci">
          <div class="cih">95% confidence interval ({seType === 'ols' ? 'textbook' : 'Newey–West'} s.e. {model.se.toFixed(3)})</div>
          <div class="cib" aria-hidden="true">
            <span class="zero" style={`left:${pcCI(0)}`}></span>
            <span class="bar" style={`left:${pcCI(model.lo)};width:calc(${pcCI(model.hi)} - ${pcCI(model.lo)})`}></span>
            <span class="pt" style={`left:${pcCI(model.b)}`}></span>
          </div>
          <p class="words small">From {model.lo >= 0 ? '+' : '−'}{Math.abs(model.lo).toFixed(2)} to {model.hi >= 0 ? '+' : '−'}{Math.abs(model.hi).toFixed(2)}.
            {#if model.lo > 0 || model.hi < 0}Zero is <b>outside</b> the interval: the data rule out "no association" at the 5% level.{:else}Zero is <b>inside</b> the interval: the data cannot rule out "no association".{/if}</p>
        </div>
        <p class="words small muted">The mortgage rate moves with unemployment (r = {model.rUn.toFixed(2)}) and with gas (r = {model.rGas.toFixed(2)}). Leave them out and the mortgage rate gets credit, or blame, for what they did.</p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 290px; }
  .terms { display: inline-flex; flex-wrap: wrap; gap: .4rem 1rem; align-items: center; }
  .terms span { color: var(--muted); }
  .terms label { display: inline-flex; gap: .35rem; align-items: center; cursor: pointer; color: var(--text); }
  .terms input { accent-color: var(--accent); width: 15px; height: 15px; }
  .grp { display: inline-flex; align-items: center; gap: .45rem; flex-wrap: wrap; }
  .lab { color: var(--muted); }
  .hf { display: grid; gap: .8rem; font-size: .82rem; }
  .legend { display: flex; flex-wrap: wrap; gap: .3rem .8rem; color: var(--text-2); font-size: .78rem; }
  .legend i { display: inline-block; width: 9px; height: 9px; border-radius: 50%; margin-right: .3rem; vertical-align: -1px; }
  .stat-v { font-size: 1.3rem !important; }
  .words { margin: 0; line-height: 1.45; color: var(--text); }
  .words.small { font-size: .78rem; color: var(--text-2); }
  .words.muted { color: var(--muted); }
  .cih { font-weight: 650; color: var(--text-2); margin-bottom: .35rem; font-size: .78rem; }
  .cib { position: relative; height: 18px; background: var(--surface-2); border-radius: 4px; margin-bottom: .4rem; }
  .cib .zero { position: absolute; top: -3px; bottom: -3px; width: 2px; margin-left: -1px; background: var(--text-2); }
  .cib .bar { position: absolute; top: 6px; height: 6px; border-radius: 3px; background: var(--c-fitted); opacity: .75; transition: left .35s, width .35s; }
  .cib .pt { position: absolute; top: 3px; width: 12px; height: 12px; margin-left: -6px; border-radius: 50%; background: var(--c-fitted); border: 2px solid var(--surface); transition: left .35s; }
  @media (prefers-reduced-motion: reduce) { .cib .bar, .cib .pt { transition: none; } }
</style>
