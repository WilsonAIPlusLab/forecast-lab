<script lang="ts">
  // Signature explorable 1: alpha is a memory dial. Bars = the weight SES gives each past month,
  // drawn on the same time axis as the data and the one-step SES forecasts they produce.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, futureDates, ym, type Pt } from '../../lib/ts';
  import { C, plotStyle, fmt, watchLayout } from '../../lib/viz/theme';
  import { sesRun, sesBestAlpha, sesWeight } from './models';

  const SERIES = {
    infl: { label: 'Monthly inflation', unit: '% m/m', dec: 2, note: 'CPI-U, all items, seasonally adjusted: month-on-month % change (log difference). The October 2025 CPI was never published because of the federal government shutdown; it is linearly interpolated here' },
    houst: { label: 'Housing starts', unit: 'thousand units, SAAR', dec: 0, note: 'Housing starts, seasonally adjusted annual rate' },
    gas: { label: 'Gasoline price', unit: '$/gallon', dec: 2, note: 'Regular gasoline, monthly average of weekly prices, not seasonally adjusted' },
  } as const;
  type K = keyof typeof SERIES;
  let sid: K = $state('infl');
  let alpha = $state(0.6);
  let data: Pt[] = $state([]);
  let best = $state(0.5);
  let top: HTMLDivElement, bars: HTMLDivElement;
  const reduce = typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;

  async function load() {
    let d: Pt[];
    if (sid === 'infl') {
      const s = await loadSeries('CPIAUCSL', { start: '2009-12-01' });
      d = s.data.slice(1).map((p, i) => ({ date: p.date, value: 100 * Math.log(p.value / s.data[i].value) }));
    } else if (sid === 'houst') d = (await loadSeries('HOUST', { start: '2010-01-01' })).data;
    else d = (await loadSeries('GASREGW', { start: '2010-01-01', to: 'month' })).data;
    data = d;
    best = sesBestAlpha(d.map((p) => p.value));
  }

  const fit = $derived.by(() => {
    if (!data.length) return null;
    const y = data.map((p) => p.value);
    const r = sesRun(y, alpha), rb = sesRun(y, best);
    const n = y.length - 1;
    return { ...r, rmse: Math.sqrt(r.sse / n), rmseBest: Math.sqrt(rb.sse / n) };
  });
  const halfLife = $derived(alpha >= 1 ? 1 : Math.ceil(Math.log(0.5) / Math.log(1 - alpha)));
  const S = $derived(SERIES[sid]);

  function draw() {
    if (!top || !bars || !fit || !data.length) return;
    const W = top.clientWidth;
    const show = data.slice(-72);
    const off = data.length - show.length;
    const last = data[data.length - 1].date;
    const fut = futureDates(last, 12, 12);
    const domain = [show[0].date, fut[fut.length - 1]];
    const fitted = show.map((p, i) => ({ date: p.date, v: fit.fitted[off + i] }));
    const fc = [{ date: last, v: fit.level }, ...fut.map((d) => ({ date: d, v: fit.level }))];
    const style = { ...plotStyle(), fontSize: '12px' };
    const ml = 52;
    const chart = Plot.plot({
      width: W, height: Math.max(230, Math.min(300, W * 0.36)), marginLeft: ml, marginRight: 64, marginTop: 14, marginBottom: 22,
      style, x: { domain, label: null, axis: null }, y: { grid: true, nice: true, label: null, tickFormat: fmt },
      ariaLabel: `${S.label} with simple exponential smoothing forecasts at alpha ${alpha.toFixed(2)}`,
      marks: [
        sid === 'infl' ? Plot.ruleY([0], { stroke: C.borderStrong }) : null,
        Plot.lineY(show, { x: 'date', y: 'value', stroke: C.history, strokeWidth: 1.25, strokeOpacity: 0.85 }),
        Plot.dot(show, { x: 'date', y: 'value', fill: C.history, r: 1.6, fillOpacity: 0.7 }),
        Plot.lineY(fitted, { x: 'date', y: 'v', stroke: C.fitted, strokeWidth: 2.4 }),
        Plot.lineY(fc, { x: 'date', y: 'v', stroke: C.forecast, strokeWidth: 3, strokeDasharray: '5 4' }),
        Plot.ruleX([last], { stroke: C.borderStrong, strokeDasharray: '3 4' }),
        Plot.text([fc[fc.length - 1]], { x: 'date', y: 'v', text: () => 'Forecast', dx: 6, textAnchor: 'start', fill: C.forecast, fontWeight: 650, fontSize: 12, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' } as any),
        Plot.text([fitted[fitted.length - 1]], { x: 'date', y: 'v', text: () => 'SES level', dy: -12, textAnchor: 'end', fill: C.fitted, fontWeight: 650, fontSize: 12, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' } as any),
        Plot.tip(show.map((p, i) => ({ ...p, f: fit.fitted[off + i] })), Plot.pointerX({ x: 'date', y: 'value', title: (r: any) => `${ym(r.date)}\nActual: ${r.value.toFixed(S.dec)} ${S.unit}\nSES forecast made the month before: ${r.f.toFixed(S.dec)}\nError: ${(r.value - r.f).toFixed(S.dec)}` })),
      ].filter(Boolean) as any,
    });
    top.replaceChildren(chart);
    // weights, on the same time axis: observation j months back gets alpha (1-alpha)^j
    const wts = show.map((p, i) => ({ date: p.date, w: sesWeight(alpha, show.length - 1 - i), j: show.length - 1 - i }));
    const wmax = Math.max(alpha, 0.05);
    const b = Plot.plot({
      width: W, height: 120, marginLeft: ml, marginRight: 64, marginTop: 8, marginBottom: 26,
      style, x: { domain, label: null }, y: { domain: [0, wmax], label: null, ticks: 2, tickFormat: (d: number) => `${Math.round(d * 100)}%`, grid: true },
      ariaLabel: `Weights given to past months at alpha ${alpha.toFixed(2)}; half the weight is on the last ${halfLife} months`,
      marks: [
        Plot.rectY(wts, { x1: (r: any) => new Date(+r.date - 12 * 864e5), x2: (r: any) => new Date(+r.date + 12 * 864e5), y: 'w', fill: (r: any) => (r.j < halfLife ? C.fitted : C.muted), fillOpacity: (r: any) => (r.j < halfLife ? 0.95 : 0.55) }),
        Plot.text(['Weight in next month’s forecast'], { frameAnchor: 'top-left', dx: 4, dy: 0, fill: C.text2, fontSize: 12, fontWeight: 600 }),
        Plot.tip(wts, Plot.pointerX({ x: 'date', y: 'w', title: (r: any) => `${ym(r.date)} (${r.j} months back)\nWeight: ${(r.w * 100).toFixed(2)}%` })),
      ],
    });
    bars.replaceChildren(b);
  }

  // "Find the best alpha": glide the slider to the optimum (instant under reduced motion)
  function findBest() {
    if (reduce) { alpha = best; return; }
    const a0 = alpha, t0 = performance.now(), dur = 420;
    const step = (t: number) => {
      const k = Math.min(1, (t - t0) / dur), e = 1 - (1 - k) ** 3;
      alpha = +(a0 + (best - a0) * e).toFixed(2);
      if (k < 1) requestAnimationFrame(step); else alpha = best;
    };
    requestAnimationFrame(step);
  }

  $effect(() => { fit; alpha; draw(); });
  $effect(() => { sid; load(); });
  onMount(() => { const a = watchLayout(top, draw); return a; });
</script>

<Explorable title="Alpha is a memory dial" caption={`Drag <b>α</b>. The bars show how much weight each past month gets in the forecast: α on the latest month, α(1−α) on the one before, and so on. Cyan bars hold half of the total weight. The cyan line is the forecast SES would have made each month, one step ahead. ${S.note}. Data: FRED. The best α here is found by a grid search on one-step squared errors (R's <code>ses()</code> also estimates the starting level, so its α can differ slightly).`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Series">
      {#each Object.entries(SERIES) as [k, x]}<button class:on={sid === k} onclick={() => (sid = k as K)}>{x.label}</button>{/each}
    </div>
    <label class="sl">α <input type="range" min="0.02" max="1" step="0.01" bind:value={alpha} aria-label="Smoothing parameter alpha" aria-valuetext={`alpha ${alpha.toFixed(2)}`} /> <b>{alpha.toFixed(2)}</b></label>
    <button class="btn btn-ghost btn-sm" onclick={findBest}>Find the best α</button>
  {/snippet}
  {#snippet aside()}
    {#if fit}
      <div class="ro" aria-live="polite">
        <div class="stat"><span class="stat-v">{halfLife}</span><span class="stat-l">{halfLife === 1 ? 'month holds' : 'months hold'} half the weight</span></div>
        <div class="stat"><span class="stat-v">{fit.rmse.toFixed((S.dec as number) === 0 ? 1 : 3)}</span><span class="stat-l">one-step RMSE, {S.unit}</span></div>
        <div class="stat"><span class="stat-v sm">{fit.sse.toPrecision(4)}</span><span class="stat-l">sum of squared one-step errors (SSE)</span></div>
        <p class="verdict">
          {#if Math.abs(alpha - best) < 0.005}
            <b>This is the best α ({best.toFixed(2)}).</b>
          {:else}
            Best α is <b>{best.toFixed(2)}</b>; you are {((fit.rmse / fit.rmseBest - 1) * 100).toFixed(1)}% worse.
          {/if}
          {#if best >= 0.95}
            With α near 1, SES is just the naive forecast: last month is all you need.
          {:else if best < 0.35}
            A low α averages over many months: the noise is large relative to real shifts.
          {:else}
            A middle α: recent months matter most, but one month alone is too noisy.
          {/if}
        </p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={top} class="chart"></div>
  <div bind:this={bars} class="bars"></div>
</Explorable>

<style>
  .chart { min-height: 230px; }
  .bars { min-height: 120px; margin-top: -4px; }
  .ro { display: grid; gap: .9rem; font-size: .84rem; }
  .stat-v.sm { font-size: 1.1rem; }
  .verdict { color: var(--text-2); margin: 0; line-height: 1.5; }
</style>
