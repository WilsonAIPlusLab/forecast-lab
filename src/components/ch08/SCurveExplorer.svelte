<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { rng } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { loadRecData, fitLogit, fitLine, logLik, sigmoid, mon, type Row } from './model';

  // The student shapes a logistic curve with two sliders: where it crosses 50% and how steep it is.
  // p(spread) = σ(a + b·spread) with b = −steep and a = steep·mid. "Fit" snaps to the MLE (Newton/IRLS, as glm does).
  let rows: Row[] = $state.raw([]);
  let mid = $state(0.5);
  let steep = $state(0.4);
  let showLine = $state(false);
  let el: HTMLDivElement;
  let x: number[] = $state.raw([]), y: number[] = $state.raw([]);
  let jit: number[] = [];
  let mle = $state({ a: 0, b: 0, ll: 0 });
  let lpm = $state({ a: 0, b: 0 });
  let latest: Row | null = $state(null);
  let anim = 0;

  const a = $derived(steep * mid);
  const b = $derived(-steep);
  const ll = $derived(x.length ? logLik(a, b, x, y) : 0);
  const llFlat = $derived(x.length ? logLik(Math.log(y.filter(Boolean).length / (y.length - y.filter(Boolean).length)), 0, x, y) : 0);
  const score = $derived(mle.ll ? Math.max(0, Math.min(1, (ll - llFlat) / (mle.ll - llFlat))) : 0);
  const atMLE = $derived(Math.abs(a - mle.a) < 0.03 && Math.abs(b - mle.b) < 0.03);

  onMount(() => {
    let stop = () => {};
    loadRecData().then((all) => {
    latest = all[all.length - 1];
    rows = all.filter((r) => r.ahead !== null);
    x = rows.map((r) => r.spread); y = rows.map((r) => r.ahead!);
    const g = rng(8);
    jit = rows.map(() => (g.u() - 0.5) * 0.14);
    mle = fitLogit(x, y);
    lpm = fitLine(x, y);
    draw();
    stop = watchLayout(el, draw);
    });
    return () => { stop(); cancelAnimationFrame(anim); };
  });

  function fit() {
    cancelAnimationFrame(anim);
    const m0 = mid, s0 = steep, m1 = -mle.a / mle.b, s1 = -mle.b;
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduce) { mid = m1; steep = s1; return; }
    const t0 = performance.now(), D = 420;
    const step = (t: number) => {
      const k = Math.min(1, (t - t0) / D), e = 1 - Math.pow(1 - k, 3);
      mid = m0 + (m1 - m0) * e; steep = s0 + (s1 - s0) * e;
      if (k < 1) anim = requestAnimationFrame(step);
    };
    anim = requestAnimationFrame(step);
  }
  function reset() { cancelAnimationFrame(anim); mid = 0.5; steep = 0.4; }

  function draw() {
    if (!el || !rows.length) return;
    const W = el.clientWidth;
    const grid = Array.from({ length: 151 }, (_, i) => -3 + i * 0.05);
    const curve = grid.map((s) => ({ s, p: sigmoid(a + b * s) }));
    const line = grid.map((s) => ({ s, p: lpm.a + lpm.b * s }));
    const pts = rows.map((r, i) => ({ s: r.spread, yy: r.ahead! + (r.ahead ? -1 : 1) * Math.abs(jit[i]), r }));
    const recCol = C.s[1], calmCol = C.s[0];
    const marks: any[] = [
      Plot.ruleY([0, 1], { stroke: C.borderStrong }),
      Plot.ruleX([0], { stroke: C.borderStrong, strokeDasharray: '3,4' }),
      Plot.text([{ s: 0.06, p: 1.1 }], { x: 's', y: 'p', text: () => '← inverted curve | normal curve →', textAnchor: 'middle', fill: C.muted, fontSize: 12 }),
      Plot.dot(pts, { x: 's', y: 'yy', r: 2.6, fill: (d: any) => (d.r.ahead ? recCol : calmCol), fillOpacity: (d: any) => (d.r.ahead ? 0.85 : 0.35) }),
      Plot.text([{ s: 4.4, p: 0.85 }], { x: 's', y: 'p', text: () => 'Recession 12 months later', textAnchor: 'end', fill: recCol, fontSize: 12, fontWeight: 650 }),
      Plot.text([{ s: 4.4, p: 0.15 }], { x: 's', y: 'p', text: () => 'No recession 12 months later', textAnchor: 'end', fill: calmCol, fontSize: 12, fontWeight: 650 }),
    ];
    if (showLine) {
      marks.push(Plot.lineY(line, { x: 's', y: 'p', stroke: C.s[3], strokeWidth: 2, strokeDasharray: '6,4' }));
      marks.push(Plot.text([{ s: 3.2, p: lpm.a + lpm.b * 3.2 }], { x: 's', y: 'p', text: () => 'Straight line (LPM) dips below 0', dy: 14, textAnchor: 'middle', fill: C.s[3], fontSize: 12, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }));
    }
    marks.push(Plot.lineY(curve, { x: 's', y: 'p', stroke: C.forecast, strokeWidth: 3 }));
    if (mid > -3 && mid < 4.5) marks.push(Plot.dot([{ s: mid, p: 0.5 }], { x: 's', y: 'p', r: 5.5, fill: C.forecast, stroke: C.surface, strokeWidth: 2 }));
    marks.push(Plot.tip(pts, Plot.pointer({ x: 's', y: 'yy', maxRadius: 14, title: (d: any) => `${mon(d.r.date)}: spread ${d.r.spread.toFixed(2)} pct. pts\n${mon(d.r.target)}: ${d.r.ahead ? 'recession' : 'no recession'}\nYour curve: P = ${(100 * sigmoid(a + b * d.r.spread)).toFixed(0)}%` })));
    const chart = Plot.plot({
      width: W, height: Math.max(300, Math.min(400, W * 0.55)), marginLeft: 46, marginRight: 14, marginTop: 30, marginBottom: 40,
      style: plotStyle(), x: { domain: [-3, 4.5], label: '10y minus 3m spread this month (pct. points) →', labelAnchor: 'right', grid: false },
      y: { domain: [-0.2, 1.15], ticks: [0, 0.25, 0.5, 0.75, 1], tickFormat: (v: number) => `${Math.round(v * 100)}%`, label: '↑ P(recession 12 months later)', grid: true },
      marks,
    });
    chart.setAttribute('aria-label', `Scatter of monthly term spreads against whether a recession followed 12 months later, with your logistic curve. Log-likelihood ${ll.toFixed(1)}.`);
    chart.setAttribute('role', 'img');
    el.replaceChildren(chart);
  }
  $effect(() => { a; b; showLine; draw(); });
</script>

<Explorable title="Bend the S-curve until it fits every month since 1959" caption="Each dot is one month since 1959: its yield-curve spread (left–right) and whether the economy was in recession 12 months later (top row) or not (bottom row; dots are spread out vertically so you can see them). Shape the violet curve with the two sliders and watch the <b>log-likelihood</b>: it rewards high probabilities on the top-row months and low ones on the bottom row. Then press <b>Fit</b> to jump to the maximum, exactly what <code>glm()</code> finds. Hover a dot for its month.">
  {#snippet controls()}
    <label class="sl">Crosses 50% at <input type="range" min="-3" max="3" step="0.05" bind:value={mid} aria-label="Spread at which the curve crosses 50 percent" aria-valuetext={`${mid.toFixed(2)} percentage points`} oninput={() => cancelAnimationFrame(anim)} /> <b>{mid.toFixed(2)}</b></label>
    <label class="sl">Steepness <input type="range" min="0" max="3" step="0.05" bind:value={steep} aria-label="Steepness of the curve" aria-valuetext={steep.toFixed(2)} oninput={() => cancelAnimationFrame(anim)} /> <b>{steep.toFixed(2)}</b></label>
    <div class="seg" role="group" aria-label="Actions">
      <button class:on={atMLE} onclick={fit}>Fit (maximum likelihood)</button>
      <button class:on={showLine} aria-pressed={showLine} onclick={() => (showLine = !showLine)}>Straight line</button>
      <button onclick={reset}>Reset</button>
    </div>
  {/snippet}
  {#snippet aside()}
    <div class="ms" aria-live="polite">
      <div class="stat"><span class="stat-v">{ll.toFixed(1)}</span><span class="stat-l"><b>Log-likelihood</b> of your curve (closer to 0 is better). Best possible: {mle.ll.toFixed(1)}</span></div>
      <div class="meter" aria-hidden="true"><i style={`width:${(100 * score).toFixed(1)}%`}></i></div>
      <div class="stat-l">{atMLE ? 'You are at the maximum: these are the glm() estimates.' : ll < llFlat ? `Worse than a flat line at the base rate (${llFlat.toFixed(1)}). Keep going.` : `${(100 * score).toFixed(0)}% of the way from a flat line to the best fit`}</div>
      <div class="eq">log-odds = <b>{a.toFixed(2)}</b> {b < 0 ? '−' : '+'} <b>{Math.abs(b).toFixed(2)}</b> × spread</div>
      <div class="rd">
        <div><span>Inverted curve, spread −1</span><b>{(100 * sigmoid(a - b)).toFixed(0)}%</b></div>
        <div><span>Flat curve, spread 0</span><b>{(100 * sigmoid(a)).toFixed(0)}%</b></div>
        {#if latest}<div><span>{mon(latest.date)}, spread {latest.spread.toFixed(2)}</span><b>{(100 * sigmoid(a + b * latest.spread)).toFixed(0)}%</b></div>{/if}
      </div>
    </div>
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 300px; }
  .ms { display: grid; gap: .7rem; font-size: .82rem; }
  .meter { height: 6px; border-radius: 3px; background: var(--surface-3); overflow: hidden; }
  .meter i { display: block; height: 100%; background: var(--c-forecast); }
  .eq { font: .8rem var(--font-mono); color: var(--text-2); border-top: 1px dashed var(--border); padding-top: .6rem; }
  .eq b { color: var(--text); font-variant-numeric: tabular-nums; }
  .rd { display: grid; gap: .3rem; }
  .rd div { display: flex; justify-content: space-between; gap: .6rem; color: var(--muted); }
  .rd b { color: var(--text); font-variant-numeric: tabular-nums; }
</style>
