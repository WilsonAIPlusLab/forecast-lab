<script lang="ts">
  // Toggle trend, seasonal dummies and a COVID pulse dummy; watch the fitted line step month by month.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, ym, type Pt } from '../../lib/ts';
  import { C, plotStyle, fmt, watchLayout } from '../../lib/viz/theme';
  import { ols } from './ols';

  const SERIES = [
    { id: 'RSXFSN', label: 'Retail sales', unit: '$ millions, NSA', scale: 1 },
    { id: 'HOUSTNSA', label: 'Housing starts', unit: 'thousands of units, NSA', scale: 1 },
  ];
  const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  let sid = $state('RSXFSN');
  let useTrend = $state(true), useSeason = $state(false), useCovid = $state(false);
  let data: Pt[] = $state([]);
  let el: HTMLDivElement, elBars: HTMLDivElement;

  async function load() { data = (await loadSeries(sid, { start: '2012-01-01' })).data; }

  const model = $derived.by(() => {
    if (!data.length) return null;
    const X = data.map((p, i) => {
      const r = [1];
      if (useTrend) r.push(i + 1);
      if (useSeason) for (let m = 1; m < 12; m++) r.push(p.date.getMonth() === m ? 1 : 0);
      if (useCovid) r.push(p.date.getFullYear() === 2020 && p.date.getMonth() === 3 ? 1 : 0);
      return r;
    });
    const f = ols(X, data.map((p) => Math.log(p.value)));
    const off = useTrend ? 2 : 1;
    const seas = MON.map((m, j) => ({ m, pct: useSeason && j > 0 ? 100 * (Math.exp(f.beta[off + j - 1]) - 1) : 0 }));
    const covid = useCovid ? 100 * (Math.exp(f.beta[f.beta.length - 1]) - 1) : null;
    return { f, seas, covid, rows: data.map((p, i) => ({ date: p.date, a: p.value, fit: Math.exp(f.fitted[i]) })) };
  });

  function draw() {
    if (!el || !model) return;
    const W = el.clientWidth;
    const unit = SERIES.find((s) => s.id === sid)!.unit;
    const covidPt = model.rows.find((r) => r.date.getFullYear() === 2020 && r.date.getMonth() === 3);
    const chart = Plot.plot({
      width: W, height: Math.max(280, Math.min(380, W * 0.45)), marginLeft: 64, marginRight: 70, marginTop: 16,
      style: plotStyle(), x: { label: null }, y: { grid: true, tickFormat: fmt, label: null },
      ariaLabel: `Actual ${sid} and fitted values from a regression on the selected terms`,
      marks: [
        Plot.lineY(model.rows, { x: 'date', y: 'fit', stroke: C.fitted, strokeWidth: 2.2, strokeOpacity: 0.9, curve: 'step-after' }),
        Plot.lineY(model.rows, { x: 'date', y: 'a', stroke: C.history, strokeWidth: 1.4 }),
        Plot.text(model.rows, Plot.selectLast({ x: 'date', y: 'fit', text: () => 'Fitted', dx: 8, dy: 9, textAnchor: 'start', fill: C.fitted, fontSize: 12, fontWeight: 650 })),
        Plot.text(model.rows, Plot.selectLast({ x: 'date', y: 'a', text: () => 'Actual', dx: 8, dy: -9, textAnchor: 'start', fill: C.history, fontSize: 12, fontWeight: 650 })),
        covidPt ? Plot.text([covidPt], { x: 'date', y: 'a', text: () => (useCovid ? 'April 2020: absorbed by the pulse dummy' : 'April 2020: stores closed'), dy: 16, textAnchor: 'middle', fill: C.text2, fontSize: 12, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }) : null,
        Plot.tip(model.rows, Plot.pointerX({ x: 'date', y: 'a', title: (r: any) => `${ym(r.date)}\nActual: ${fmt(r.a)} (${unit})\nFitted: ${fmt(Math.round(r.fit))}\nMiss: ${(100 * (r.a / r.fit - 1)).toFixed(1)}%` })),
      ],
    });
    el.replaceChildren(chart);
    if (elBars) {
      const bars = Plot.plot({
        width: W, height: 150, marginLeft: 64, marginRight: 70, marginTop: 18, marginBottom: 26,
        style: plotStyle(), x: { label: null, domain: MON, padding: 0.25 }, y: { grid: true, label: null, tickFormat: (v: number) => v + '%', domain: [Math.min(-5, ...model.seas.map((s) => s.pct)), Math.max(35, ...model.seas.map((s) => s.pct))] },
        ariaLabel: 'Seasonal dummy coefficients: percentage gap from January for each month',
        marks: [
          Plot.barY(model.seas, { x: 'm', y: 'pct', fill: (d: any) => (d.pct >= 0 ? C.fitted : C.danger), fillOpacity: useSeason ? 0.75 : 0.15 }),
          Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
          useSeason ? Plot.text(model.seas.filter((s) => s.m !== 'Jan' && s.pct >= 0), { x: 'm', y: 'pct', text: (d: any) => '+' + d.pct.toFixed(0) + '%', dy: -8, fill: C.text2, fontSize: 12 }) : null,
          useSeason ? Plot.text(model.seas.filter((s) => s.pct < 0), { x: 'm', y: 'pct', text: (d: any) => d.pct.toFixed(0) + '%', dy: 10, fill: C.text2, fontSize: 12 }) : null,
          !useSeason ? Plot.text(['Seasonal dummies are off: every month gets the same intercept'], { frameAnchor: 'middle', fill: C.muted, fontSize: 12, text: (d: any) => d }) : null,
        ],
      });
      elBars.replaceChildren(bars);
    }
  }
  $effect(() => { model; draw(); });
  $effect(() => { sid; load(); });
  onMount(() => watchLayout(el, draw));
</script>

<Explorable title="Dummy variables: one intercept shift per month"
  caption="The model is fitted to log sales, so each bar is a month's percentage gap from January, holding the trend fixed. Turn on <b>Monthly dummies</b> and watch the cyan fitted line start to step up and down with the calendar. Then try the <b>April 2020</b> pulse dummy, which is 1 in a single month and 0 everywhere else. Both series are <b>not seasonally adjusted</b>, from January 2012. Data: FRED (RSXFSN, HOUSTNSA).">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Series">
      {#each SERIES as s}<button class:on={sid === s.id} onclick={() => (sid = s.id)}>{s.label}</button>{/each}
    </div>
    <div class="terms" role="group" aria-label="Terms in the regression">
      <span>Terms:</span>
      <label><input type="checkbox" bind:checked={useTrend} /> Trend</label>
      <label><input type="checkbox" bind:checked={useSeason} /> Monthly dummies</label>
      <label><input type="checkbox" bind:checked={useCovid} /> April 2020 pulse</label>
    </div>
  {/snippet}
  {#snippet aside()}
    {#if model}
      <div class="ms">
        <div class="stat"><span class="stat-v">{model.f.r2.toFixed(3)}</span><span class="stat-l"><b>R²</b> on the log scale: share of the variation explained</span></div>
        <div class="stat"><span class="stat-v">±{(100 * model.f.sigma).toFixed(1)}%</span><span class="stat-l"><b>Typical miss</b> (residual standard error, in log points ≈ %)</span></div>
        <div class="stat"><span class="stat-v">{model.f.p}</span><span class="stat-l">Coefficients estimated</span></div>
        {#if model.covid !== null}<p class="note">The pulse dummy says April 2020 ran <b>{Math.abs(model.covid).toFixed(0)}%</b> {model.covid < 0 ? 'below' : 'above'} what trend and season predict.</p>{/if}
        <p class="note muted">Why 11 dummies, not 12? January is the baseline inside the intercept. A 12th dummy would duplicate the intercept exactly: the <i>dummy variable trap</i>.</p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart"></div>
  <div class="bars-h">Intercept shift by month: % above or below January, the baseline month</div>
  <div bind:this={elBars}></div>
</Explorable>

<style>
  .chart { min-height: 280px; }
  .terms { display: inline-flex; flex-wrap: wrap; gap: .4rem 1rem; align-items: center; }
  .terms span { color: var(--muted); }
  .terms label { display: inline-flex; gap: .35rem; align-items: center; cursor: pointer; color: var(--text); }
  .terms input { accent-color: var(--accent); width: 15px; height: 15px; }
  .bars-h { font-size: .8rem; font-weight: 650; color: var(--text-2); margin: .6rem 0 0 4px; }
  .ms { display: grid; gap: .85rem; }
  .note { font-size: .8rem; color: var(--text-2); margin: 0; line-height: 1.45; }
  .note.muted { color: var(--muted); font-size: .76rem; }
</style>
