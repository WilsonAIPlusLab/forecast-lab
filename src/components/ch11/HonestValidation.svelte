<script lang="ts">
  // Chapter 11 · Explorable 7: shuffled vs time-ordered validation. On a trending series (e-commerce),
  // random K-fold cross-validation says a forest on LEVELS is as good as one on GROWTH RATES; time-ordered
  // folds reveal the extrapolation trap, and agree with what really happened from 2023 onward.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, type Pt } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { growForest, predictForest, mulberry } from './tree';

  const NT = 60, K = 5, YEARS = [2017, 2018, 2019, 2020, 2021];
  let data: Pt[] = [];
  let scheme: 'random' | 'time' = $state('random');
  let reveal = $state(false);
  let busy = $state(true);
  let elMap: HTMLDivElement, elBar: HTMLDivElement;
  type Res = { random: { level: number; growth: number }; time: { level: number; growth: number }; truth: { level: number; growth: number }; folds: { random: number[]; time: number[][] }; dates: Date[]; nTest: number };
  let res: Res | null = $state(null);

  onMount(() => {
    loadSeries('MRTSSM4541USS', { start: '2010-01-01' }).then((s) => {
      data = s.data;
      setTimeout(compute, 30); // let the frame paint first
    });
    const a = watchLayout(elMap, draw), b = watchLayout(elBar, draw);
    return () => { a(); b(); };
  });

  function compute() {
    const v = data.map((p) => p.value);
    const gr = v.map((x, i) => (i ? 100 * Math.log(x / v[i - 1]) : NaN));
    const end = data.findIndex((p) => p.date.getFullYear() === 2023);
    const all: number[] = [];
    for (let t = 4; t < end; t++) all.push(t);   // rows need lags 1-3 (and growth needs one more month)
    const feat = (mode: string, t: number) => (mode === 'level' ? [v[t - 1], v[t - 2], v[t - 3]] : [gr[t - 1], gr[t - 2], gr[t - 3]]);
    const fit = (mode: string, ts: number[]) => growForest(ts.map((t) => feat(mode, t)), ts.map((t) => (mode === 'level' ? v[t] : gr[t])), { nTrees: NT, mtry: 2, minSplit: 5, seed: 1 });
    // one-month-ahead forecast of the dollar level; growth forecasts are compounded from last month's actual level
    const pred = (mode: string, F: any, t: number) => { const p = predictForest(F, feat(mode, t)); return mode === 'level' ? p : v[t - 1] * Math.exp(p / 100); };
    // random folds: shuffle the rows, deal them into K piles
    const rng = mulberry(5), sh = all.slice();
    for (let k = sh.length - 1; k > 0; k--) { const m = Math.floor(rng() * (k + 1)); [sh[k], sh[m]] = [sh[m], sh[k]]; }
    const foldOf = new Map<number, number>(); sh.forEach((t, i) => foldOf.set(t, i % K));
    const out: any = { random: {}, time: {}, truth: {} };
    for (const mode of ['level', 'growth']) {
      let e = 0;
      for (let f = 0; f < K; f++) {
        const F = fit(mode, all.filter((t) => foldOf.get(t) !== f));
        for (const t of all) if (foldOf.get(t) === f) e += Math.abs(v[t] - pred(mode, F, t));
      }
      out.random[mode] = e / all.length;
      let e2 = 0, n2 = 0;
      for (const yr of YEARS) {
        const cut = data.findIndex((p) => p.date.getFullYear() === yr + 1);
        const F = fit(mode, all.filter((t) => t < cut));
        for (let t = cut; t < cut + 12; t++) { e2 += Math.abs(v[t] - pred(mode, F, t)); n2++; }
      }
      out.time[mode] = e2 / n2;
      const F = fit(mode, all);
      let e3 = 0, n3 = 0;
      for (let t = end; t < v.length; t++) { e3 += Math.abs(v[t] - pred(mode, F, t)); n3++; }
      out.truth[mode] = e3 / n3;
      out.nTest = n3;
    }
    out.dates = all.map((t) => data[t].date);
    out.folds = {
      random: all.map((t) => foldOf.get(t)!),
      time: YEARS.map((yr) => all.map((t) => { const y = data[t].date.getFullYear(); return y <= yr ? 0 : y === yr + 1 ? 1 : 2; })),
    };
    res = out;
    busy = false;
  }

  function draw() {
    if (!res || !elMap || !elBar) return;
    const W = elMap.clientWidth;
    if (W < 280 || elBar.clientWidth < 280) return;   // not laid out yet: watchLayout redraws once it has a real width
    const cells: { date: Date; row: string; kind: string }[] = [];
    for (let f = 0; f < K; f++) {
      res.dates.forEach((d, i) => {
        const kind = scheme === 'random' ? (res!.folds.random[i] === f ? 'validate' : 'train') : ['train', 'validate', 'unused'][res!.folds.time[f][i]];
        cells.push({ date: d, row: scheme === 'random' ? `fold ${f + 1}` : `to ${YEARS[f]}`, kind });
      });
    }
    const col = { train: C.history, validate: C.forecast, unused: C.border } as Record<string, string>;
    elMap.replaceChildren(Plot.plot({
      width: W, height: 150, marginLeft: 56, marginRight: 10, marginTop: 6, marginBottom: 26, style: plotStyle(),
      x: { label: null }, y: { label: null, tickSize: 0, padding: 0.18 },
      marks: [Plot.barX(cells, { x1: 'date', x2: (d: any) => new Date(+d.date + 30 * 864e5), y: 'row', fill: (d: any) => col[d.kind], fillOpacity: (d: any) => (d.kind === 'train' ? 0.35 : 1) })],
      ariaLabel: scheme === 'random' ? 'Five shuffled folds: validation months are scattered across 2010 to 2022' : 'Five time-ordered folds: each trains on the years up to a December and validates on the next 12 months',
    } as any));
    // one bar per row: the cross-validation estimate for each forest, plus (after Reveal) what really happened
    const est = scheme === 'random' ? 'shuffled CV' : 'time-ordered CV';
    const rows: { key: string; real: boolean; v: number }[] = [
      { key: `Levels · ${est}`, real: false, v: res[scheme].level / 1000 },
      ...(reveal ? [{ key: 'Levels · real, 2023+', real: true, v: res.truth.level / 1000 }] : []),
      { key: `Growth · ${est}`, real: false, v: res[scheme].growth / 1000 },
      ...(reveal ? [{ key: 'Growth · real, 2023+', real: true, v: res.truth.growth / 1000 }] : []),
    ];
    const Wb = elBar.clientWidth;
    elBar.replaceChildren(Plot.plot({
      width: Wb, height: 34 * rows.length + 46, marginLeft: 150, marginRight: 70, marginTop: 6, marginBottom: 36, style: plotStyle(),
      x: { grid: true, ticks: [0, 5, 10, 15], label: 'average miss, one month ahead ($ billions) →', domain: [0, Math.max(15, ...rows.map((r) => r.v)) * 1.05] },
      y: { label: null, domain: rows.map((r) => r.key), tickSize: 0, padding: 0.25 },
      marks: [
        Plot.barX(rows, { x: 'v', y: 'key', fill: (d: any) => (d.real ? C.actual : C.forecast), rx: 3 }),
        Plot.text(rows, { x: 'v', y: 'key', dx: 5, textAnchor: 'start', text: (d: any) => `$${d.v.toFixed(2)} bn`, fill: C.text, fontSize: 12, fontWeight: 650 }),
        Plot.ruleX([0], { stroke: C.borderStrong }),
      ],
      ariaLabel: `Average one-month-ahead miss: ${rows.map((r) => `${r.key} ${r.v.toFixed(2)} billion dollars`).join('; ')}`,
    } as any));
  }
  $effect(() => { res; scheme; reveal; draw(); });

  const verdict = $derived.by(() => {
    if (!res) return '';
    const L = res[scheme].level, G = res[scheme].growth, r = L / G;
    if (scheme === 'random') return `Shuffled folds call it a tie (levels $${(L / 1000).toFixed(2)} bn vs growth $${(G / 1000).toFixed(2)} bn). Every validation month sits between training months, so the level forest only has to interpolate.`;
    return `Time-ordered folds say growth wins by ${r.toFixed(1)}× (levels $${(L / 1000).toFixed(2)} bn vs growth $${(G / 1000).toFixed(2)} bn). Each validation year lies after its training years, so the level forest must forecast above anything it has seen, and it cannot.`;
  });
</script>

<Explorable title="Shuffled cross-validation hides the trap; time-ordered folds expose it" caption="Two random forests (three lags each) forecast U.S. e-commerce sales one month ahead: one on the <b>level</b> ($), one on the <b>monthly growth rate</b> (%), converted back to dollars. The top strip shows the five validation folds over 2010–2022 (bright purple = validation months, faint = training months, gray = not used yet). <b>Shuffled folds</b> are what generic machine-learning tutorials do; <b>time-ordered folds</b> stand at the end of each December from 2017 to 2021 and forecast the next 12 months. Compare the two estimates, then press <b>Reveal</b> to see the error each forest actually made from January 2023 onward. Data: FRED MRTSSM4541USS, $ billions, seasonally adjusted.">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="How to validate">
      <button class:on={scheme === 'random'} aria-pressed={scheme === 'random'} onclick={() => (scheme = 'random')}>Shuffled folds</button>
      <button class:on={scheme === 'time'} aria-pressed={scheme === 'time'} onclick={() => (scheme = 'time')}>Time-ordered folds</button>
    </div>
    <button class="btn" aria-pressed={reveal} onclick={() => (reveal = !reveal)}>{reveal ? 'Hide' : 'Reveal'} what happened in 2023+</button>
  {/snippet}
  {#snippet aside()}
    {#if busy}<p class="hint">Growing {NT * (2 * K + 2 * YEARS.length + 2)} trees…</p>{/if}
    {#if res}
      <p class="story" aria-live="polite">{verdict}</p>
      {#if reveal}
        <p class="story">What really happened: levels missed by <b>${(res.truth.level / 1000).toFixed(2)} bn</b> a month, growth by <b>${(res.truth.growth / 1000).toFixed(2)} bn</b>. Only the time-ordered folds pointed the right way.</p>
      {/if}
      <p class="hint">Average miss = mean absolute error of one-month-ahead forecasts. The 2023+ test has {res.nTest} months.</p>
    {/if}
  {/snippet}
  <div bind:this={elMap} class="map"></div>
  <div class="key" aria-hidden="true"><span class="sw tr"></span>training <span class="sw va"></span>validation {#if scheme === 'time'}<span class="sw un"></span>not used yet (the future){/if}</div>
  <div bind:this={elBar} class="bars"></div>
</Explorable>

<style>
  .map { min-height: 150px; }
  .bars { min-height: 130px; margin-top: .6rem; }
  .key { display: flex; flex-wrap: wrap; align-items: center; gap: .35rem .6rem; font-size: .76rem; color: var(--muted); margin: .1rem 0 0 56px; }
  .sw { display: inline-block; width: 12px; height: 10px; border-radius: 2px; margin-left: .3rem; }
  .sw.tr { background: color-mix(in srgb, var(--c-history) 35%, transparent); }
  .sw.va { background: var(--c-forecast); }
  .sw.un { background: var(--border); }
  .btn { all: unset; cursor: pointer; font: 600 .78rem var(--font-ui); padding: .38rem .8rem; border-radius: 8px; border: 1px solid var(--border-strong); color: var(--text); background: var(--bg); }
  .btn:hover { background: var(--surface-2); }
  .btn:focus-visible { outline: 2px solid var(--accent-2); }
  .story { font-size: .86rem; color: var(--text-2); margin: 0 0 .7rem; line-height: 1.45; }
  .hint { font-size: .74rem; color: var(--muted); margin: 0; }
  @media (max-width: 520px) { .key { margin-left: 0; } }
</style>
