<script lang="ts">
  // Least squares by hand: drag a line through real data; each residual is drawn as an actual square.
  import { onMount, untrack } from 'svelte';
  import * as d3 from 'd3';
  import Explorable from '../Explorable.svelte';
  import { loadSeries } from '../../lib/ts';
  import { C, watchLayout } from '../../lib/viz/theme';
  import { joinMonthly } from './ols';

  const SAMPLES = [
    { k: 'boom', label: '1993–2007', from: 1993, to: 2007 },
    { k: 'recovery', label: '2009–2019', from: 2009, to: 2019 },
    { k: 'all', label: 'All, 1993–2026', from: 1993, to: 2100 },
  ];
  let sample = $state('boom');
  let all: { date: Date; x: number; y: number }[] = [];
  let pts: { date: Date; x: number; y: number }[] = $state([]);
  // The line is stored by its height at the left and right edge of the x-range.
  let yL = $state(1600), yR = $state(1600);
  let el: HTMLDivElement;
  let anim = 0;
  const reduce = typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const XMIN = 2.5, XMAX = 9.5;

  const fit = $derived.by(() => {
    if (!pts.length) return null;
    const n = pts.length, mx = d3.mean(pts, (p) => p.x)!, my = d3.mean(pts, (p) => p.y)!;
    let sxy = 0, sxx = 0, sst = 0;
    for (const p of pts) { sxy += (p.x - mx) * (p.y - my); sxx += (p.x - mx) ** 2; sst += (p.y - my) ** 2; }
    const b1 = sxy / sxx, b0 = my - b1 * mx;
    const sse = d3.sum(pts, (p) => (p.y - b0 - b1 * p.x) ** 2);
    return { b0, b1, sse, sst, mx, my, n };
  });
  const slope = $derived((yR - yL) / (XMAX - XMIN));
  const icpt = $derived(yL - slope * XMIN);
  const mySSE = $derived(d3.sum(pts, (p) => (p.y - icpt - slope * p.x) ** 2));
  const ratio = $derived(fit ? mySSE / fit.sse : 1);

  async function load() {
    const [hs, mr] = await Promise.all([loadSeries('HOUST'), loadSeries('MORTGAGE30US', { to: 'month' })]);
    all = joinMonthly([hs.data, mr.data]).map((r) => ({ date: r.date, y: r.v[0], x: r.v[1] }));
    pick();
  }
  function pick() {
    const s = SAMPLES.find((x) => x.k === sample)!;
    pts = all.filter((p) => p.date.getFullYear() >= s.from && p.date.getFullYear() <= s.to);
    const my = d3.mean(pts, (p) => p.y)!;
    cancelAnimationFrame(anim); yL = my; yR = my; // start flat at the mean: the Chapter 3 "mean" forecast
  }
  function snap() {
    if (!fit) return;
    const tL = fit.b0 + fit.b1 * XMIN, tR = fit.b0 + fit.b1 * XMAX;
    if (reduce) { yL = tL; yR = tR; return; }
    const sL = yL, sR = yR, t0 = performance.now(), dur = 420;
    cancelAnimationFrame(anim);
    const step = (now: number) => {
      const k = d3.easeCubicOut(Math.min(1, (now - t0) / dur));
      yL = sL + (tL - sL) * k; yR = sR + (tR - sR) * k;
      if (k < 1) anim = requestAnimationFrame(step);
    };
    anim = requestAnimationFrame(step);
  }

  let svgSel: d3.Selection<SVGSVGElement, unknown, null, undefined> | null = null;
  let sx: d3.ScaleLinear<number, number>, sy: d3.ScaleLinear<number, number>;
  function build() {
    if (!el || !pts.length) return;
    const W = el.clientWidth, H = Math.max(320, Math.min(440, W * 0.62)), ml = 54, mr = 16, mt = 14, mb = 40;
    sx = d3.scaleLinear().domain([XMIN, XMAX]).range([ml, W - mr]);
    sy = d3.scaleLinear().domain([300, 2400]).range([H - mb, mt]);
    const svg = d3.create('svg').attr('width', W).attr('height', H).attr('role', 'img')
      .attr('aria-label', 'Scatter of monthly housing starts against the 30-year mortgage rate, with a movable line and squared residuals');
    svg.append('g').attr('transform', `translate(${ml},0)`).call(d3.axisLeft(sy).ticks(6).tickSize(-(W - ml - mr)).tickFormat((v) => d3.format(',')(v as number)))
      .call((g) => { g.select('.domain').remove(); g.selectAll('line').attr('stroke', C.border); g.selectAll('text').attr('fill', C.muted).style('font-size', '12px'); });
    svg.append('g').attr('transform', `translate(0,${H - mb})`).call(d3.axisBottom(sx).ticks(8).tickFormat((v) => v + '%'))
      .call((g) => { g.select('.domain').attr('stroke', C.border); g.selectAll('line').remove(); g.selectAll('text').attr('fill', C.muted).style('font-size', '12px'); });
    svg.append('text').attr('x', W - mr).attr('y', H - 6).attr('text-anchor', 'end').attr('fill', C.muted).style('font-size', '12px').text('30-year mortgage rate (%)');
    svg.append('text').attr('x', ml + 4).attr('y', mt + 12).attr('fill', C.muted).style('font-size', '12px').text('Housing starts (thousands, SAAR)');
    svg.append('clipPath').attr('id', 'ls-clip').append('rect').attr('x', ml).attr('y', mt).attr('width', W - ml - mr).attr('height', H - mt - mb);
    svg.append('g').attr('class', 'sq').attr('clip-path', 'url(#ls-clip)');
    svg.append('g').attr('class', 'res');
    svg.append('g').attr('class', 'pts').selectAll('circle').data(pts).join('circle')
      .attr('cx', (p) => sx(p.x)).attr('cy', (p) => sy(p.y)).attr('r', 2.6).attr('fill', C.history).attr('fill-opacity', 0.85);
    svg.append('line').attr('class', 'fitline').attr('stroke', C.forecast).attr('stroke-width', 3);
    const handles = svg.append('g').attr('class', 'handles');
    for (const side of ['L', 'R'] as const) {
      handles.append('circle').attr('class', 'h' + side).attr('r', 10).attr('fill', C.forecast).attr('stroke', C.surface).attr('stroke-width', 3)
        .attr('tabindex', 0).attr('role', 'slider').style('cursor', 'ns-resize')
        .attr('aria-label', side === 'L' ? 'Left end of the line; use up and down arrows' : 'Right end of the line; use up and down arrows')
        .call(d3.drag<SVGCircleElement, unknown>().on('start', () => cancelAnimationFrame(anim)).on('drag', (ev) => {
          const v = Math.max(0, Math.min(3000, sy.invert(ev.y))); if (side === 'L') yL = v; else yR = v;
        }))
        .on('keydown', (ev: KeyboardEvent) => {
          const d = ev.key === 'ArrowUp' ? 25 : ev.key === 'ArrowDown' ? -25 : 0; if (!d) return; ev.preventDefault();
          if (side === 'L') yL += d; else yR += d;
        });
    }
    // Middle grab: drag the whole line up/down
    svg.select('line.fitline').style('cursor', 'move').call(d3.drag<any, unknown>().on('start', () => cancelAnimationFrame(anim)).on('drag', (ev) => {
      const dv = sy.invert(ev.y) - sy.invert(ev.y - ev.dy); yL += dv; yR += dv;
    }) as any);
    svgSel = svg;
    el.replaceChildren(svg.node()!);
    update();
  }
  function update() {
    if (!svgSel || !sx) return;
    const at = (x: number) => icpt + slope * x;
    svgSel.select('line.fitline').attr('x1', sx(XMIN)).attr('x2', sx(XMAX)).attr('y1', sy(yL)).attr('y2', sy(yR));
    svgSel.select('.hL').attr('cx', sx(XMIN)).attr('cy', sy(yL)).attr('aria-valuetext', `${Math.round(yL)} thousand starts at ${XMIN}%`);
    svgSel.select('.hR').attr('cx', sx(XMAX)).attr('cy', sy(yR)).attr('aria-valuetext', `${Math.round(yR)} thousand starts at ${XMAX}%`);
    // Each square's side is the residual measured in screen pixels, so it is a true square on screen.
    svgSel.select('g.sq').selectAll('rect').data(pts).join('rect')
      .attr('x', (p) => sx(p.x))
      .attr('y', (p) => Math.min(sy(p.y), sy(at(p.x))))
      .attr('width', (p) => Math.abs(sy(p.y) - sy(at(p.x))))
      .attr('height', (p) => Math.abs(sy(p.y) - sy(at(p.x))))
      .attr('fill', C.danger).attr('fill-opacity', 0.05).attr('stroke', C.danger).attr('stroke-opacity', 0.22).attr('stroke-width', 0.75);
    svgSel.select('g.res').selectAll('line').data(pts).join('line')
      .attr('x1', (p) => sx(p.x)).attr('x2', (p) => sx(p.x)).attr('y1', (p) => sy(p.y)).attr('y2', (p) => sy(at(p.x)))
      .attr('stroke', C.danger).attr('stroke-opacity', 0.5).attr('stroke-width', 1);
  }
  $effect(() => { yL; yR; update(); });
  $effect(() => { sample; untrack(() => { if (all.length) { pick(); build(); } }); });
  onMount(() => { load().then(build); return watchLayout(el, build); });

  const f0 = (v: number) => Math.round(v).toLocaleString();
  const big = (v: number) => (v / 1e6).toFixed(2) + ' mn';
</script>

<Explorable title="Least squares by hand: make the red squares as small as you can"
  caption="Each dot is one month: the 30-year mortgage rate (monthly average of weekly Freddie Mac rates) and housing starts (thousands of units, seasonally adjusted annual rate). Drag the two purple handles, or drag the line itself; with the keyboard, focus a handle and use ↑ ↓. Every red square has a side equal to one residual, so their total area is the <b>sum of squared residuals</b>. Ordinary least squares is the line with the smallest possible total. Then switch to the full 1993–2026 sample. Data: FRED (HOUST, MORTGAGE30US).">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Sample period">
      {#each SAMPLES as s}<button class:on={sample === s.k} onclick={() => (sample = s.k)}>{s.label}</button>{/each}
    </div>
    <button class="btn-snap" onclick={snap}>Snap to least squares</button>
    <button class="btn-snap ghost" onclick={pick}>Reset to the mean</button>
  {/snippet}
  {#snippet aside()}
    {#if fit}
      <div class="ls">
        <div class="stat"><span class="stat-v">{big(mySSE)}</span><span class="stat-l"><b>Your</b> total square area (sum of squared residuals)</span></div>
        <div class="meter" aria-hidden="true"><i style={`width:${Math.min(100, (fit.sse / mySSE) * 100)}%`}></i></div>
        <div class="stat"><span class="stat-v small">{big(fit.sse)}</span><span class="stat-l">The least-squares minimum</span></div>
        <p class="verdict" aria-live="polite">
          {#if ratio < 1.001}<b class="good">You found it.</b> No other line has less total area.
          {:else}Your line's squares are <b>{((ratio - 1) * 100).toFixed(ratio < 1.1 ? 1 : 0)}%</b> bigger than they need to be.{/if}
        </p>
        <div class="eq">
          <div><span>Your line</span> starts = {f0(icpt)} {slope < 0 ? '−' : '+'} {f0(Math.abs(slope))} × rate</div>
          <div><span>OLS line</span> starts = {f0(fit.b0)} {fit.b1 < 0 ? '−' : '+'} {f0(Math.abs(fit.b1))} × rate</div>
          <div class="r2"><span>R²</span> {(1 - fit.sse / fit.sst).toFixed(2)} · {fit.n} months</div>
        </div>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 320px; touch-action: none; }
  .btn-snap { all: unset; cursor: pointer; font: 600 .8rem var(--font-ui); padding: .38rem .8rem; border-radius: 8px; background: var(--accent); color: #fff; }
  .btn-snap.ghost { background: transparent; color: var(--text-2); border: 1px solid var(--border-strong); }
  .btn-snap:focus-visible { outline: 2px solid var(--accent-2); outline-offset: 2px; }
  .ls { display: grid; gap: .7rem; font-size: .84rem; }
  .stat-v.small { font-size: 1.1rem !important; color: var(--text-2) !important; }
  .meter { height: 6px; border-radius: 3px; background: color-mix(in srgb, var(--danger) 35%, transparent); overflow: hidden; }
  .meter i { display: block; height: 100%; background: var(--good); }
  .verdict { margin: 0; color: var(--text-2); }
  .good { color: var(--good); }
  .eq { font-variant-numeric: tabular-nums; display: grid; gap: .35rem; border-top: 1px dashed var(--border); padding-top: .7rem; color: var(--text); font-size: .8rem; }
  .eq span { display: block; font-size: .75rem; color: var(--muted); }
  .eq .r2 { color: var(--text-2); }
</style>
