<script lang="ts">
  // Signature explorable 2: Holt's linear trend vs damped trend, 36 months ahead, from three real origins.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, futureDates, ym, type Series } from '../../lib/ts';
  import { C, plotStyle, fmt, watchLayout } from '../../lib/viz/theme';
  import { holtFit } from './models';

  const ORIGINS = [
    { d: '2019-12', label: 'Dec 2019', story: 'Nobody saw COVID coming: lockdowns pushed shopping online, and actual sales shot far above every trend line.' },
    { d: '2020-12', label: 'Dec 2020', story: 'At the peak of the lockdown boom, the slope is steep. A straight-line trend keeps climbing; reality flattened out in 2021.' },
    { d: '2023-08', label: 'Aug 2023', story: 'A calmer period. A light touch of damping (φ ≈ 0.98) tracks the next three years well.' },
  ];
  const H = 36;
  let oi = $state(1);
  let beta = $state(0.1);
  let phi = $state(0.9);
  let s = $state<Series | null>(null);
  let el: HTMLDivElement;

  onMount(async () => { s = await loadSeries('MRTSSM4541USS', { start: '2010-01-01' }); });

  const res = $derived.by(() => {
    if (!s) return null;
    const key = ORIGINS[oi].d;
    const i = s.data.findIndex((p) => p.date.getFullYear() === +key.slice(0, 4) && p.date.getMonth() === +key.slice(5) - 1);
    const train = s.data.slice(0, i + 1), test = s.data.slice(i + 1, i + 1 + H);
    const y = train.map((p) => p.value);
    const cur = holtFit(y, beta, phi, H), lin = holtFit(y, beta, 1, H);
    const dates = futureDates(train[train.length - 1].date, H, 12);
    const mae = (f: number[]) => test.reduce((a, p, k) => a + Math.abs(p.value - f[k]), 0) / test.length;
    return { train, test, cur, lin, dates, maeCur: mae(cur.forecast), maeLin: mae(lin.forecast) };
  });

  function draw() {
    if (!el || !res) return;
    const { train, test, cur, lin, dates } = res;
    const W = el.clientWidth;
    if (W < 260) return;                               // skip transient tiny widths (e.g. mid-resize)
    const show = train.slice(-60);
    const o = train[train.length - 1];
    const fcRow = (f: number[]) => [{ date: o.date, v: o.value }, ...f.map((v, k) => ({ date: dates[k], v }))];
    const lab = (txt: string, r: any, fill: string, dy = 0) => Plot.text([r], { x: 'date', y: 'v', text: () => txt, dx: 6, dy, textAnchor: 'start', fill, fontWeight: 650, fontSize: 12, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' } as any);
    const fl = fcRow(lin.forecast), fd = fcRow(cur.forecast);
    const yEnd = (a: any[]) => a[a.length - 1].v;
    const sep = Math.abs(yEnd(fl) - yEnd(fd)) < 0.06 * yEnd(fl);
    const marks: any[] = [
      Plot.rectX([{ a: dates[0], b: dates[H - 1] }], { x1: 'a', x2: 'b', fill: C.actual, fillOpacity: 0.05 }),
      Plot.lineY(show, { x: 'date', y: 'value', stroke: C.history, strokeWidth: 2 }),
      Plot.lineY(test, { x: 'date', y: 'value', stroke: C.actual, strokeWidth: 2.2, strokeDasharray: '5 3' }),
      Plot.ruleX([o.date], { stroke: C.borderStrong, strokeDasharray: '3 4' }),
      Plot.text([o.date], { x: (d: any) => d, frameAnchor: 'top', dx: 6, dy: 2, textAnchor: 'start', text: () => 'Forecast starts', fill: C.muted, fontSize: 12 }),
      Plot.lineY(fl, { x: 'date', y: 'v', stroke: C.s[1], strokeWidth: phi === 1 ? 3 : 1.6, strokeOpacity: phi === 1 ? 1 : 0.7, strokeDasharray: phi === 1 ? undefined : '2 3' }),
      Plot.lineY(fd, { x: 'date', y: 'v', stroke: C.forecast, strokeWidth: 3 }),
      lab('Linear trend (φ = 1)', fl[fl.length - 1], C.s[1], sep ? -9 : 0),
      phi < 1 ? lab(`Damped (φ = ${phi.toFixed(2)})`, fd[fd.length - 1], C.forecast, sep ? 9 : 0) : null,
      lab('Actual', { date: test[test.length - 1]?.date, v: test[test.length - 1]?.value }, C.actual),
      Plot.tip(test.map((p, k) => ({ date: p.date, a: p.value, l: lin.forecast[k], d: cur.forecast[k] })), Plot.pointerX({ x: 'date', y: 'a', title: (r: any) => `${ym(r.date)} ($ millions, SA)\nActual: ${fmt(r.a)}\nLinear trend: ${fmt(r.l)}\nDamped: ${fmt(r.d)}` })),
    ].filter(Boolean);
    if (phi < 1 && isFinite(cur.limit) && cur.limit < 1e7) marks.push(
      Plot.ruleY([cur.limit], { stroke: C.forecast, strokeOpacity: 0.5, strokeDasharray: '4 4', strokeWidth: 1.25 }),
      Plot.text([cur.limit], { y: (d: any) => d, frameAnchor: 'left', dx: 4, dy: -8, textAnchor: 'start', text: () => `Damped forecast levels off near ${fmt(cur.limit)}`, fill: C.forecast, fontSize: 12, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' } as any));
    const chart = Plot.plot({
      width: W, height: Math.max(300, Math.min(420, W * 0.5)), marginLeft: 62, marginRight: W < 520 ? 120 : 150, marginTop: 28,
      style: { ...plotStyle(), fontSize: '12px' }, x: { label: null }, y: { grid: true, nice: true, label: '$ millions (SA)', tickFormat: fmt },
      ariaLabel: `E-commerce sales with linear and damped trend forecasts from ${ORIGINS[oi].label}`,
      marks,
    });
    el.replaceChildren(chart);
  }
  $effect(() => { res; draw(); });
  onMount(() => watchLayout(el, draw));
  const better = $derived(res ? res.maeCur < res.maeLin : false);
</script>

<Explorable title="Should the trend go on forever? Damping says no" caption={`U.S. e-commerce sales, $ millions, <b>seasonally adjusted</b> (MRTSSM4541USS, FRED), so only level and trend remain. Pick a forecast origin, then set <b>β</b> (how fast the slope reacts) and <b>φ</b> (how fast the slope fades: φ = 1 never fades). α is re-estimated by a grid search each time. The gold dashed line is what actually happened over the next 36 months.`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Forecast origin">
      {#each ORIGINS as x, i}<button class:on={oi === i} onclick={() => (oi = i)}>{x.label}</button>{/each}
    </div>
    <label class="sl">β <input type="range" min="0" max="0.5" step="0.01" bind:value={beta} aria-label="Trend smoothing beta" aria-valuetext={`beta ${beta.toFixed(2)}`} /> <b>{beta.toFixed(2)}</b></label>
    <label class="sl">φ <input type="range" min="0.8" max="1" step="0.01" bind:value={phi} aria-label="Damping parameter phi" aria-valuetext={`phi ${phi.toFixed(2)}`} /> <b>{phi.toFixed(2)}</b></label>
  {/snippet}
  {#snippet aside()}
    {#if res}
      <div class="ro" aria-live="polite">
        <div class="stat"><span class="stat-v">{fmt(res.maeLin)}</span><span class="stat-l">36-month MAE, linear trend ($ mn)</span></div>
        <div class="stat"><span class="stat-v" class:good={better}>{fmt(res.maeCur)}</span><span class="stat-l">36-month MAE, φ = {phi.toFixed(2)} ($ mn)</span></div>
        <p class="verdict">{#if phi === 1}Lower φ below 1 to damp the trend.{:else if better}<b>Damping wins</b> from this origin, by {Math.round((1 - res.maeCur / res.maeLin) * 100)}%.{:else}<b>Damping loses</b> from this origin: the trend really did continue (or accelerate).{/if}</p>
        <p class="story">{ORIGINS[oi].story}</p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 300px; }
  .ro { display: grid; gap: .9rem; font-size: .84rem; }
  .good { color: var(--good); }
  .verdict { color: var(--text-2); margin: 0; }
  .story { color: var(--muted); margin: 0; font-size: .8rem; line-height: 1.5; }
</style>
