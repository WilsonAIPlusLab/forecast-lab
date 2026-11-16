<script lang="ts">
  // Chapter 11 · Explorable 1: a sliding window walks along real retail sales and drops one
  // supervised-learning row per month into a feature table. A toggle makes the rolling mean leak.
  import { onMount, onDestroy } from 'svelte';
  import { fly } from 'svelte/transition';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, ym, type Pt } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';

  const FIRST = 12;           // first target index (needs a full year of history for lag 12)
  const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  let data: Pt[] = $state([]);
  let t = $state(FIRST);      // index of the current target month
  let leak = $state(false);
  let playing = $state(false);
  let timer: any;
  let el: HTMLDivElement;
  let reduce = $state(false);

  const bn = (v: number) => v / 1000; // $ millions -> $ billions
  const f1 = (v: number) => bn(v).toFixed(1);

  onMount(() => {
    reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
    loadSeries('RSXFSN', { start: '2021-01-01', end: '2024-12-01' }).then((s) => (data = s.data));
    return watchLayout(el, draw);
  });
  onDestroy(() => clearInterval(timer));

  function step() { if (data.length && t < data.length - 1) t += 1; else pause(); }
  function play() {
    if (t >= data.length - 1) t = FIRST;
    clearInterval(timer); playing = true;
    timer = setInterval(step, reduce ? 1200 : 750);
  }
  function pause() { clearInterval(timer); playing = false; }
  function reset() { pause(); t = FIRST; }

  // the table: one row per target month from FIRST to t
  function rowAt(i: number) {
    const v = (k: number) => data[i - k].value;
    const roll = leak ? (v(0) + v(1) + v(2)) / 3 : (v(1) + v(2) + v(3)) / 3;
    return { i, date: data[i].date, month: MON[data[i].date.getMonth()], lag12: v(12), lag2: v(2), lag1: v(1), roll, y: v(0) };
  }
  const rows = $derived(data.length ? Array.from({ length: t - FIRST + 1 }, (_, k) => rowAt(FIRST + k)).slice(-6) : []);
  const built = $derived(t - FIRST + 1);

  function draw() {
    if (!el || !data.length) return;
    const W = el.clientWidth;
    if (W < 200) return;   // not laid out yet: watchLayout redraws once it has a real width
    const pts = data.map((p, i) => ({ date: p.date, v: bn(p.value), i, known: i < t }));
    const at = (k: number) => pts[t - k];
    const roles = [
      { k: 12, label: 'lag 12', col: C.s[5] },
      { k: 2, label: 'lag 2', col: C.fitted },
      { k: 1, label: 'lag 1', col: C.fitted },
    ];
    const winLo = leak ? t - 2 : t - 3, winHi = leak ? t : t - 1;
    const half = 14 * 864e5; // half a month, for band edges
    const marks: any[] = [
      // rolling-mean window band
      Plot.rectX([{ a: new Date(+pts[winLo].date - half), b: new Date(+pts[winHi].date + half) }], { x1: 'a', x2: 'b', fill: leak ? C.danger : C.fitted, fillOpacity: leak ? 0.16 : 0.1 }),
      Plot.text([pts[winLo].date], { x: (d: any) => d, frameAnchor: 'top', dy: 2, dx: -10, textAnchor: 'start', text: () => (leak ? '3-month mean: includes the target!' : '3-month mean window'), fill: leak ? C.danger : C.muted, fontSize: 12, fontWeight: 600 }),
      // unknown future
      Plot.rectX([{ a: new Date(+pts[t].date + half), b: new Date(+pts[pts.length - 1].date + half) }], { x1: 'a', x2: 'b', fill: C.muted, fillOpacity: 0.07 }),
      t < pts.length - 2 ? Plot.text([pts[pts.length - 1].date], { x: (d: any) => d, frameAnchor: 'top-right', dy: 2, textAnchor: 'end', text: () => 'not known yet', fill: C.muted, fontSize: 12 }) : null,
      Plot.lineY(pts.filter((p) => p.i <= t), { x: 'date', y: 'v', stroke: C.history, strokeWidth: 1.8 }),
      Plot.lineY(pts.filter((p) => p.i >= t), { x: 'date', y: 'v', stroke: C.history, strokeWidth: 1.25, strokeOpacity: 0.3 }),
      Plot.dot(pts, { x: 'date', y: 'v', r: 2, fill: C.history, fillOpacity: (p: any) => (p.i <= t ? 0.7 : 0.25) }),
      ...roles.map((r) => Plot.dot([at(r.k)], { x: 'date', y: 'v', r: 5.5, fill: r.col, stroke: C.surface, strokeWidth: 1.5 })),
      ...roles.map((r) => Plot.text([at(r.k)], { x: 'date', y: 'v', text: () => r.label, dy: r.k === 2 ? 16 : -12, fill: r.col, fontSize: 12, fontWeight: 650, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' })),
      Plot.dot([at(0)], { x: 'date', y: 'v', r: 7, fill: C.actual, stroke: C.surface, strokeWidth: 1.5 }),
      Plot.text([at(0)], { x: 'date', y: 'v', text: () => 'target', dy: -14, fill: C.actual, fontSize: 12, fontWeight: 700, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
      Plot.tip(pts, Plot.pointerX({ x: 'date', y: 'v', title: (p: any) => `${ym(p.date)}\nRetail sales: $${p.v.toFixed(1)} bn` })),
    ];
    el.replaceChildren(Plot.plot({
      width: W, height: Math.max(220, Math.min(280, W * 0.36)), marginLeft: 44, marginRight: 12, marginTop: 22,
      style: plotStyle(), x: { label: null }, y: { grid: true, label: '$ billions', tickFormat: (d: number) => d.toFixed(0) },
      marks: marks.filter(Boolean),
      ariaLabel: `Retail sales with the month ${ym(pts[t].date)} highlighted as the target and its lags highlighted as features`,
    } as any));
  }
  $effect(() => { t; leak; data; draw(); });
</script>

<Explorable title="Every month becomes one row of training data" caption="Press <b>Play</b> (or <b>Step</b>). The gold dot is the month we want to predict, the <b>target</b>. The colored dots are its <b>features</b>, values that were already known before the target month began. Each step drops one new row into the table. Then switch on the leak: the 3-month window slides over the target itself, and the feature quietly contains the answer. Data: U.S. retail sales excluding food services, $ billions, not seasonally adjusted (FRED RSXFSN).">
  {#snippet controls()}
    <button class="btn btn-sm" onclick={() => (playing ? pause() : play())} aria-pressed={playing}>{playing ? 'Pause' : 'Play'}</button>
    <button class="btn btn-sm btn-ghost" onclick={() => { pause(); step(); }} disabled={!data.length || t >= data.length - 1}>Step one month</button>
    <label class="tg"><input type="checkbox" bind:checked={leak} /> Let the rolling mean include the target month</label>
  {/snippet}
  <div bind:this={el} class="chart"></div>
  <div class="tbl-wrap">
    <div class="tbl-h"><span>The supervised-learning table</span><span class="count" aria-live="polite">{built} row{built === 1 ? '' : 's'} built{#if t !== FIRST}<button class="link" onclick={reset}>start over</button>{/if}</span></div>
    <table class="ft">
      <thead>
        <tr><th>Row</th><th>Month</th><th class="c-l12">Lag 12</th><th class="c-l">Lag 2</th><th class="c-l">Lag 1</th><th class:bad={leak}>3-mo mean{leak ? ' ⚠' : ''}</th><th class="c-y">Target</th></tr>
      </thead>
      <tbody>
        {#each rows as r (r.i)}
          <tr in:fly={{ y: -10, duration: reduce ? 0 : 320 }} class:cur={r.i === t}>
            <td>{ym(r.date)}</td><td>{r.month}</td><td>{f1(r.lag12)}</td><td>{f1(r.lag2)}</td><td>{f1(r.lag1)}</td>
            <td class:bad={leak}>{f1(r.roll)}</td><td class="y">{f1(r.y)}</td>
          </tr>
        {/each}
      </tbody>
    </table>
    <p class="note">{#if leak}<b class="bad">Leak.</b> This mean averages the target with the two months before it, so at forecast time it cannot be computed. A model trained on it looks brilliant in testing and fails in production.{:else}All features come from months <i>before</i> the target, so you could compute this row on the first day of {data.length ? MON[data[t].date.getMonth()] : 'the month'}. Values in $ billions.{/if}</p>
  </div>
</Explorable>

<style>
  .chart { min-height: 220px; }
  .tg { display: inline-flex; align-items: center; gap: .45rem; cursor: pointer; }
  .tg input { accent-color: var(--danger); width: 16px; height: 16px; }
  .btn-sm { padding: .45em .85em; font-size: .8rem; }
  .tbl-wrap { margin-top: .6rem; }
  .tbl-h { display: flex; justify-content: space-between; align-items: baseline; gap: 1rem; font-size: .82rem; font-weight: 650; color: var(--text-2); margin-bottom: .3rem; }
  .count { color: var(--muted); font-weight: 500; font-variant-numeric: tabular-nums; }
  .link { all: unset; cursor: pointer; color: var(--accent-2); margin-left: .7rem; }
  .link:focus-visible { outline: 2px solid var(--accent-2); }
  .ft { width: 100%; font-size: .8rem; font-variant-numeric: tabular-nums; margin: 0; }
  .ft th, .ft td { padding: .32rem .5rem; text-align: right; white-space: nowrap; }
  .ft th:first-child, .ft td:first-child, .ft th:nth-child(2), .ft td:nth-child(2) { text-align: left; }
  .ft th.c-l12 { color: var(--c-s6); } .ft th.c-l { color: var(--c-fitted); } .ft th.c-y { color: var(--c-actual); }
  .ft td.y { color: var(--c-actual); font-weight: 650; }
  .ft tr.cur td { background: var(--surface-2); }
  .ft .bad, .bad { color: var(--danger); }
  .ft td.bad { background: color-mix(in srgb, var(--danger) 10%, transparent); font-weight: 650; }
  .note { font-size: .8rem; color: var(--muted); margin: .45rem 0 0; }
  @media (max-width: 560px) { .ft th:nth-child(2), .ft td:nth-child(2) { display: none; } }
</style>
