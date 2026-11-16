<script lang="ts">
  // Explorable: read the states of a fitted ETS model as a "receipt" for one month's forecast.
  // States come from R's ets() (src/labs/ch05/make_data.R), the same fits as the ETS lab, so the numbers match R exactly.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import data from './etsdata.json';

  const SETS = data.states as any[];
  const MON = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  const D = (s: string) => new Date(s + 'T00:00:00');
  const ymLong = (s: string) => `${MON[+s.slice(5, 7) - 1]} ${s.slice(0, 4)}`;
  const bn = (v: number, d = 1) => `$${(v / 1000).toFixed(d)} bn`;                 // $ millions -> "$x.x bn"
  const mn = (v: number) => `$${Math.round(v).toLocaleString('en-US')} million`;

  let si = $state(0);
  const S = $derived(SETS[si]);
  const nTrain = $derived(S.y.length);
  let idx = $state(119);                       // December 2024 in both data sets
  let el: HTMLDivElement;
  $effect(() => { if (idx > nTrain + 11) idx = nTrain + 11; });

  // the receipt for the selected month: training months use the one-step forecast, future months the h-step forecast
  const rc = $derived.by(() => {
    const s = S;
    if (idx < nTrain) {
      const l = s.l[idx], b = s.b[idx], sf = s.s[idx], y = s.y[idx];
      const under = l + b, fc = s.mult ? under * sf : under + sf;
      return { future: false, date: s.date[idx], h: 1, l, b, under, sf, fc, y };
    }
    const h = idx - nTrain + 1, sf = s.S[h - 1];
    const under = s.L + h * s.B, fc = s.mult ? under * sf : under + sf;
    return { future: true, date: s.fdate[h - 1], h, l: s.L, b: s.B, under, sf, fc, y: s.factual[h - 1] };
  });
  const miss = $derived(rc.y - rc.fc);
  const seasonWords = $derived(S.mult
    ? `${MON[+rc.date.slice(5, 7) - 1]} runs ${Math.abs(Math.round((rc.sf - 1) * 100))}% ${rc.sf >= 1 ? 'above' : 'below'} an average month`
    : `${MON[+rc.date.slice(5, 7) - 1]} runs ${bn(Math.abs(rc.sf))} ${rc.sf >= 0 ? 'above' : 'below'} an average month`);

  function draw() {
    if (!el) return;
    const s = S, W = el.clientWidth;
    if (W < 200) return;                                      // skip transient tiny widths (e.g. mid-resize)
    const from = 72;                                          // show from Jan 2021
    const hist = s.date.slice(from).map((d: string, i: number) => ({ date: D(d), y: s.y[from + i], l: s.l[from + i + 1] ?? s.L }));
    const fut = s.fdate.map((d: string, i: number) => ({ date: D(d), f: s.fmean[i], a: s.factual[i] }));
    const sel = { date: D(rc.date), v: rc.fc, a: rc.y, u: rc.under };
    const lab = (d: any, y: string, txt: string, fill: string, dy = 0) => Plot.text([d], { x: 'date', y, text: () => txt, dx: 6, dy, textAnchor: 'start', fill, fontSize: 12, fontWeight: 650, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' } as any);
    const c = Plot.plot({
      width: W, height: Math.max(260, Math.min(330, W * 0.42)), marginLeft: 46, marginRight: 72, marginTop: 28, marginBottom: 26,
      style: { ...plotStyle(), fontSize: '12px' },
      x: { label: null }, y: { grid: true, nice: true, label: '↑ $ billions', tickFormat: (v: number) => `${Math.round(v / 1000)}` },
      ariaLabel: `${s.label} sales in billions of dollars with the ${s.method} level and forecast; selected month ${ymLong(rc.date)}`,
      marks: [
        Plot.rectX([{ a: D(s.fdate[0]), b: D(s.fdate[11]) }], { x1: 'a', x2: 'b', fill: C.actual, fillOpacity: 0.06 }),
        Plot.lineY(hist, { x: 'date', y: 'y', stroke: C.history, strokeWidth: 1.6 }),
        Plot.lineY(hist, { x: 'date', y: 'l', stroke: C.fitted, strokeWidth: 2.4 }),
        Plot.lineY(fut, { x: 'date', y: 'a', stroke: C.actual, strokeWidth: 2, strokeDasharray: '5 3' }),
        Plot.lineY(fut, { x: 'date', y: 'f', stroke: C.forecast, strokeWidth: 2.4 }),
        lab(hist[10], 'l', 'Level', C.fitted, 16),
        lab(fut[fut.length - 1], 'f', 'Forecast', C.forecast, -8),
        Plot.ruleX([sel], { x: 'date', stroke: C.borderStrong, strokeDasharray: '3 3' }),
        Plot.dot([sel], { x: 'date', y: 'u', r: 4.5, fill: C.fitted, stroke: C.surface, strokeWidth: 1.5 }),
        Plot.dot([sel], { x: 'date', y: 'v', r: 5.5, fill: C.forecast, stroke: C.surface, strokeWidth: 1.5 }),
        Plot.dot([sel], { x: 'date', y: 'a', r: 4.5, fill: 'none', stroke: rc.future ? C.actual : C.history, strokeWidth: 2 }),
      ],
    });
    el.replaceChildren(c);
  }
  $effect(() => { idx; si; draw(); });
  onMount(() => watchLayout(el, draw));
</script>

<Explorable title="Read the model's mind: a receipt for one month's forecast" caption={`States of the model <code>ets()</code> chooses in the ETS lab, trained on January 2015 to August 2025 (U.S. Census Bureau via FRED, $ millions, not seasonally adjusted). The cyan <b>level</b> is the model's estimate of underlying sales with the seasonal pattern taken out. Drag the month slider: for a past month the receipt shows the one-step forecast the model made the month before; after August 2025 it shows the forecast made from the last data point, h months ahead (gold dashed line = what actually happened). The chart starts in 2021; the slider reaches back to 2015.`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Data set">
      {#each SETS as x, i}<button class:on={si === i} onclick={() => (si = i)}>{x.label} · {x.method}</button>{/each}
    </div>
    <label class="sl">Month <input type="range" min="0" max={nTrain + 11} step="1" bind:value={idx} aria-label="Month to read" aria-valuetext={ymLong(rc.date)} /> <b class="mo">{ymLong(rc.date).replace(/^(\w{3})\w*/, '$1')}</b></label>
  {/snippet}
  {#snippet aside()}
    <div class="ro" aria-live="polite">
      <div class="kick">{rc.future ? `Forecast made in August 2025, ${rc.h} ${rc.h === 1 ? 'month' : 'months'} ahead` : 'One-step forecast, made the month before'} · {ymLong(rc.date)}</div>
      <table class="rcpt">
        <tbody>
          <tr><td>Level{rc.future ? ' (Aug 2025)' : ''}</td><td>{bn(rc.l, 2)}</td></tr>
          <tr><td>{rc.future ? `+ ${rc.h} × slope` : '+ slope'}</td><td>+{bn(rc.h * rc.b, 2)}</td></tr>
          <tr class="sub"><td>= underlying sales</td><td>{bn(rc.under, 2)}</td></tr>
          <tr><td>{S.mult ? '× seasonal factor' : '+ seasonal index'}</td><td>{S.mult ? `× ${rc.sf.toFixed(3)}` : `${rc.sf >= 0 ? '+' : '−'}${bn(Math.abs(rc.sf), 2)}`}</td></tr>
          <tr class="tot"><td>= forecast</td><td>{bn(rc.fc, 2)}</td></tr>
          <tr><td>Actual</td><td>{bn(rc.y, 2)}</td></tr>
          <tr><td>Surprise</td><td>{miss >= 0 ? '+' : '−'}{bn(Math.abs(miss), 2)} ({miss >= 0 ? '+' : '−'}{Math.abs((100 * miss) / rc.fc).toFixed(1)}%)</td></tr>
        </tbody>
      </table>
      <p class="words">In words: underlying sales were running at about {bn(rc.l)} a month and growing by about {mn(rc.b)} a month. {seasonWords}.</p>
    </div>
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 260px; }
  .ro { display: grid; gap: .6rem; font-size: .84rem; }
  .kick { font-size: .76rem; color: var(--muted); line-height: 1.4; }
  .rcpt { width: 100%; border-collapse: collapse; font-variant-numeric: tabular-nums; margin: 0 !important; font-size: .84rem !important; }
  .rcpt td { padding: .2rem .1rem; border: 0 !important; background: none !important; }
  .rcpt td:last-child { text-align: right; font-family: var(--font-mono); color: var(--text); white-space: nowrap; }
  .rcpt tr.sub td, .rcpt tr.tot td { border-top: 1px solid var(--border) !important; }
  .rcpt tr.tot td { font-weight: 700; color: var(--accent-text); }
  .words { margin: 0; color: var(--text-2); line-height: 1.5; }
  .mo { min-width: 8ch !important; }
</style>
