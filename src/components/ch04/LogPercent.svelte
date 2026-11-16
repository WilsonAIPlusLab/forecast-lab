<script lang="ts">
  // When does "100 × b percent" stop working? Drag a log coefficient and compare the shortcut with the exact
  // percent effect, 100 × (e^b − 1), using coefficients from this chapter's own models.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';

  // Coefficients from this chapter's labs (log models; verified with tools/check_lab.R).
  const EX = [
    { b: -0.0298, name: 'Gas, +$1', long: 'Log–level car model: each extra $1 a gallon' },
    { b: -0.0627, name: 'Unemployment, +1 pt', long: 'Log–level car model: each extra point of unemployment' },
    { b: -0.1592, name: 'Chip shortage', long: 'Log–level car model: the 2021–22 chip-shortage dummy' },
    { b: 0.2209, name: 'December', long: 'Retail model: December vs January (seasonal dummy)' },
    { b: -0.2693, name: 'April 2020', long: 'Retail model: the April 2020 pulse dummy' },
  ];
  let b = $state(0.2209);
  let el: HTMLDivElement;
  onMount(() => watchLayout(el, draw));

  const approx = $derived(100 * +b), exact = $derived(100 * (Math.exp(+b) - 1));
  const near = $derived(EX.find((e) => Math.abs(e.b - +b) < 0.0026));

  function draw() {
    if (!el) return;
    const W = el.clientWidth, narrow = W < 520;
    const xs = Array.from({ length: 161 }, (_, i) => -0.8 + i * 0.01);
    const ex = xs.map((x) => ({ x, y: 100 * (Math.exp(x) - 1) }));
    const ap = xs.map((x) => ({ x, y: 100 * x }));
    const cur = { x: +b, a: 100 * +b, e: 100 * (Math.exp(+b) - 1) };
    const pts = EX.map((e) => ({ ...e, x: e.b, y: 100 * (Math.exp(e.b) - 1) }));
    const chart = Plot.plot({
      width: W, height: Math.max(290, Math.min(380, W * 0.5)), marginLeft: 50, marginRight: 16, marginTop: 16, marginBottom: 40,
      style: plotStyle(),
      x: { label: 'Log coefficient b →', domain: [-0.8, 0.8] },
      y: { grid: true, label: null, domain: [-60, 125], tickFormat: (v: number) => (v > 0 ? '+' : '') + v + '%' },
      ariaLabel: 'Percent effect implied by a log coefficient: the 100 times b shortcut (a straight line) against the exact curve e to the b minus 1',
      marks: [
        Plot.rect([0], { x1: () => -0.1, x2: () => 0.1, y1: () => -60, y2: () => 125, fill: C.good, fillOpacity: 0.08 }),
        Plot.text([0], { x: 0, y: 118, text: () => (narrow ? '|b| < 0.1' : 'Shortcut fine: |b| < 0.1'), fill: C.text2, fontSize: 12 }),
        Plot.ruleY([0], { stroke: C.borderStrong }),
        Plot.ruleX([0], { stroke: C.borderStrong }),
        Plot.line(ap, { x: 'x', y: 'y', stroke: C.muted, strokeWidth: 2, strokeDasharray: '6 4' }),
        Plot.line(ex, { x: 'x', y: 'y', stroke: C.fitted, strokeWidth: 2.5 }),
        Plot.text([ex[150]], { x: 'x', y: 'y', text: () => 'Exact: e^b − 1', dx: -6, dy: -4, textAnchor: 'end', fill: C.fitted, fontWeight: 700, fontSize: 12 }),
        Plot.text([ap[125]], { x: 'x', y: 'y', text: () => (narrow ? '100 × b' : 'Shortcut: 100 × b'), dx: 4, dy: 22, textAnchor: 'start', fill: C.muted, fontWeight: 650, fontSize: 12 }),
        Plot.dot(pts, { x: 'x', y: 'y', r: 4, fill: C.actual, stroke: C.surface, strokeWidth: 1.2 }),
        // the gold dots are named by the "Jump to" buttons and in the side panel, so they carry no labels here
        Plot.link([cur], { x1: 'x', x2: 'x', y1: 'a', y2: 'e', stroke: C.danger, strokeWidth: 2.5 }),
        Plot.dot([cur], { x: 'x', y: 'e', r: 6, fill: C.fitted, stroke: C.surface, strokeWidth: 2 }),
        Plot.dot([cur], { x: 'x', y: 'a', r: 5, fill: C.muted, stroke: C.surface, strokeWidth: 2 }),
        Plot.tip(ex, Plot.pointerX({ x: 'x', y: 'y', title: (d: any) => `b = ${d.x.toFixed(2)}\nShortcut: ${(100 * d.x).toFixed(1)}%\nExact: ${d.y.toFixed(1)}%` })),
      ],
    });
    el.replaceChildren(chart);
  }
  $effect(() => { b; draw(); });
  const pc = (v: number) => (v >= 0 ? '+' : '−') + Math.abs(v).toFixed(1) + '%';
</script>

<Explorable title="When does “100 × b percent” stop working?"
  caption="In a model of <b>log</b> sales, a coefficient b means sales are multiplied by e<sup>b</sup>, so the exact percent effect is 100 × (e<sup>b</sup> − 1). The quick reading 100 × b is the straight dashed line. Drag b, or jump to a coefficient from this chapter (gold dots). The red segment is the error of the shortcut. <b>Takeaway:</b> for |b| below about 0.1 the shortcut is fine; above that, report e<sup>b</sup> − 1. Notice the curve is lopsided: b = −0.69 means −50%, but b = +0.69 means +100%.">
  {#snippet controls()}
    <label class="sl">Coefficient b <input type="range" min="-0.8" max="0.8" step="0.005" value={b} oninput={(e) => (b = +e.currentTarget.value)} aria-label="Log coefficient b" aria-valuetext={`b = ${(+b).toFixed(3)}`} /> <b>{(+b).toFixed(3)}</b></label>
    <div class="pre" role="group" aria-label="Jump to a coefficient from this chapter">
      <span>Jump to:</span>
      {#each EX as e}<button class:on={near === e} onclick={() => (b = e.b)}>{e.name}</button>{/each}
    </div>
  {/snippet}
  {#snippet aside()}
    <div class="lp">
      {#if near}<p class="src">{near.long}: b = {near.b.toFixed(4)}</p>{/if}
      <div class="stat"><span class="stat-v sh">{pc(approx)}</span><span class="stat-l">Shortcut, 100 × b</span></div>
      <div class="stat"><span class="stat-v">{pc(exact)}</span><span class="stat-l">Exact, 100 × (e<sup>b</sup> − 1)</span></div>
      <div class="stat"><span class="stat-v gap">{Math.abs(exact - approx).toFixed(1)} pts</span><span class="stat-l">Error of the shortcut (percentage points)</span></div>
      <p class="words">{Math.abs(+b) < 0.1 ? 'Small coefficient: either reading is fine in a memo.' : 'Large coefficient: use the exact number. The shortcut ' + (exact > approx ? 'understates' : 'overstates') + ' the effect.'}</p>
    </div>
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 290px; }
  .pre { display: inline-flex; flex-wrap: wrap; gap: .35rem; align-items: center; }
  .pre span { color: var(--muted); font-size: .78rem; }
  .pre button { all: unset; cursor: pointer; font: 600 .74rem var(--font-ui); padding: .25rem .55rem; border-radius: 7px; border: 1px solid var(--border-strong); color: var(--text-2); }
  .pre button:hover, .pre button.on { color: var(--text); border-color: var(--accent); }
  .pre button:focus-visible { outline: 2px solid var(--accent-2); }
  .lp { display: grid; gap: .75rem; font-size: .82rem; }
  .src { margin: 0; color: var(--text-2); font-size: .78rem; line-height: 1.4; }
  .sh { color: var(--muted) !important; }
  .gap { color: var(--danger) !important; }
  .words { margin: 0; line-height: 1.45; color: var(--text); }
</style>
