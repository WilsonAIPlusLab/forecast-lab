<script lang="ts">
  // Shock ripple: hit one variable with a surprise and watch the effect travel through the VAR,
  // quarter by quarter. The network (left) and the impulse-response lines (right) share one clock.
  import { onMount, untrack } from 'svelte';
  import * as d3 from 'd3';
  import Explorable from '../Explorable.svelte';
  import { D, BASE, META, col, sgn, reduced, type VarKey } from './varlib';
  import { C } from '../../lib/viz/theme';

  const KEYS: VarKey[] = ['infl', 'unemp', 'ffr'];
  const H = D.meta.h;
  let imp: VarKey = $state('ffr');
  let t = $state(0); // continuous quarter clock, 0..H
  let playing = $state(false);
  let raf = 0, last = 0, started = false;
  let box: HTMLDivElement, chartsEl: HTMLDivElement, rootEl: HTMLDivElement;
  let theme = $state(0);
  const SPEED = 0.42; // seconds per quarter

  const ir = $derived(D.irf[BASE][imp]);
  const at = (k: VarKey, tt: number) => { const a = ir[k].pt, i = Math.floor(tt), f = tt - i; return i >= H ? a[H] : a[i] * (1 - f) + a[i + 1] * f; };
  const maxAbs = $derived(Object.fromEntries(KEYS.map((k) => [k, Math.max(...ir[k].pt.map(Math.abs), 1e-9)])) as Record<VarKey, number>);
  const q = $derived(Math.min(H, Math.round(t)));

  // network geometry (viewBox units)
  const W = 420, HH = 330;
  const POS: Record<string, [number, number]> = { ffr: [210, 78], infl: [92, 252], unemp: [328, 252] };
  const R0 = 38;

  function tick(now: number) {
    if (!playing) return;
    const dt = last ? (now - last) / 1000 : 0; last = now;
    t = Math.min(H, t + dt / SPEED);
    if (t >= H) { playing = false; return; }
    raf = requestAnimationFrame(tick);
  }
  function play() {
    if (t >= H) t = 0;
    if (reduced()) { stepPlay(); return; }
    playing = true; last = 0; cancelAnimationFrame(raf); raf = requestAnimationFrame(tick);
  }
  let stepTimer: any;
  function stepPlay() { // reduced motion: discrete quarter steps, no pulses
    clearInterval(stepTimer); playing = true;
    stepTimer = setInterval(() => { t = Math.min(H, Math.floor(t) + 1); if (t >= H) { clearInterval(stepTimer); playing = false; } }, 500);
  }
  function pause() { playing = false; cancelAnimationFrame(raf); clearInterval(stepTimer); }
  function pick(k: VarKey) { pause(); imp = k; t = 0; build(); play(); }

  // ── mini impulse-response charts (built with d3 once, updated per frame) ──
  let paths: { line: d3.Selection<SVGPathElement, unknown, null, undefined>; band: d3.Selection<SVGPathElement, unknown, null, undefined>; dot: d3.Selection<SVGCircleElement, unknown, null, undefined>; x: d3.ScaleLinear<number, number>; y: d3.ScaleLinear<number, number>; k: VarKey }[] = [];
  function build() {
    if (!chartsEl) return;
    chartsEl.replaceChildren();
    paths = [];
    const w = Math.max(240, chartsEl.clientWidth), h = 112, ml = 44, mr = 64, mt = 10, mb = 22;
    for (const k of KEYS) {
      const b = ir[k];
      const ext = d3.extent([...b.lo, ...b.hi, 0]) as [number, number];
      const x = d3.scaleLinear().domain([0, H]).range([ml, w - mr]);
      const y = d3.scaleLinear().domain(ext).nice(4).range([h - mb, mt]);
      const svg = d3.select(chartsEl).append('svg').attr('width', w).attr('height', h).attr('role', 'img')
        .attr('aria-label', `Response of ${META[k].label} to a ${META[imp].label} shock, quarters 0 to ${H}`);
      svg.append('g').attr('transform', `translate(${ml},0)`).call(d3.axisLeft(y).ticks(3).tickSize(-(w - ml - mr)).tickFormat((d) => (+d > 0 ? '+' : '') + d3.format('~g')(+d)))
        .call((g) => { g.select('.domain').remove(); g.selectAll('line').attr('stroke', C.border); g.selectAll('text').attr('fill', C.muted).style('font-size', '12px'); });
      svg.append('g').attr('transform', `translate(0,${h - mb})`).call(d3.axisBottom(x).tickValues([0, 4, 8, 12, 16, 20]).tickSize(0).tickPadding(6))
        .call((g) => { g.select('.domain').remove(); g.selectAll('text').attr('fill', C.muted).style('font-size', '12px'); });
      svg.append('line').attr('x1', ml).attr('x2', w - mr).attr('y1', y(0)).attr('y2', y(0)).attr('stroke', C.borderStrong).attr('stroke-width', 1.5);
      const band = svg.append('path').attr('fill', col(k)).attr('fill-opacity', 0.18);
      const line = svg.append('path').attr('fill', 'none').attr('stroke', col(k)).attr('stroke-width', 2.6).attr('stroke-linejoin', 'round');
      const dot = svg.append('circle').attr('r', 4.5).attr('fill', col(k)).attr('stroke', C.surface).attr('stroke-width', 2);
      svg.append('text').attr('x', w - mr + 8).attr('y', mt + 12).attr('fill', col(k)).style('font', '650 12px var(--font-ui)').text(META[k].short);
      paths.push({ line, band, dot, x, y, k });
    }
    update();
  }
  function update() {
    for (const p of paths) {
      const b = ir[p.k], n = Math.floor(t), pts: [number, number][] = [], lo: number[] = [], hi: number[] = [];
      for (let i = 0; i <= Math.min(n, H); i++) { pts.push([i, b.pt[i]]); lo.push(b.lo[i]); hi.push(b.hi[i]); }
      if (t > n && n < H) { const f = t - n; pts.push([t, at(p.k, t)]); lo.push(b.lo[n] * (1 - f) + b.lo[n + 1] * f); hi.push(b.hi[n] * (1 - f) + b.hi[n + 1] * f); }
      p.line.attr('d', d3.line().x((d) => p.x(d[0])).y((d) => p.y(d[1]))(pts));
      p.band.attr('d', d3.area<number>().x((_, i) => p.x(pts[i][0])).y0((_, i) => p.y(lo[i])).y1((_, i) => p.y(hi[i]))(pts.map((_, i) => i)));
      const e = pts[pts.length - 1]; p.dot.attr('cx', p.x(e[0])).attr('cy', p.y(e[1]));
    }
  }
  $effect(() => { t; imp; untrack(update); });
  $effect(() => { theme; imp; untrack(build); });

  onMount(() => {
    const ro = new ResizeObserver(() => build()); ro.observe(chartsEl);
    const th = () => theme++; window.addEventListener('theme-change', th);
    if (reduced()) t = H;
    const io = new IntersectionObserver((es) => { if (es[0].isIntersecting && !started) { started = true; if (!reduced()) play(); } }, { threshold: 0.5 });
    io.observe(rootEl);
    return () => { ro.disconnect(); io.disconnect(); window.removeEventListener('theme-change', th); cancelAnimationFrame(raf); clearInterval(stepTimer); };
  });

  // derived view state for the network
  const frac = $derived(t - Math.floor(t));
  const others = $derived(KEYS.filter((k) => k !== imp));
  const peak = $derived(Object.fromEntries(KEYS.map((k) => { const a = ir[k].pt; let j = 0; for (let i = 1; i <= H; i++) if (Math.abs(a[i]) > Math.abs(a[j])) j = i; return [k, j]; })) as Record<VarKey, number>);
  const STORY: Record<string, string> = {
    ffr: 'A surprise hike. Unemployment barely moves for a year, then climbs until about two years after the hike. Inflation first <i>rises</i> for two quarters before drifting lower: the price puzzle.',
    infl: 'An inflation surprise of 1.3 pp. Inflation stays high for years, the funds rate climbs about 0.5 pp within a year and a half (the Fed leans against it), and unemployment creeps up by almost 0.3 pp over four years.',
    unemp: 'An unemployment surprise (a weakening economy). The funds rate is cut by about 0.8 pp within a year, and inflation falls by about half a point almost at once.',
  };
  const yrs = (k: number) => (k === 0 ? 'on impact' : k < 4 ? `${k} quarter${k > 1 ? 's' : ''} later` : `${k} quarters (${(k / 4).toFixed(k % 4 ? 2 : 0).replace(/\.?0+$/, '')} yr) later`);
</script>

<div bind:this={rootEl}>
<Explorable title="One surprise, three ripples: how a shock travels through a VAR"
  caption={`Pick which variable gets the surprise. The clock runs quarter by quarter: rings show how far each variable has moved from where it would otherwise be (solid ring = above, dashed = below), and the lines on the right draw the same impulse responses with 90% bootstrap bands. Baseline ordering (inflation, unemployment, funds rate), VAR(4) on 1960–2000 quarterly data; responses to a one-standard-deviation shock, in percentage points. Data: FRED (CPIAUCSL, UNRATE, FEDFUNDS).`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Which variable is shocked">
      {#each ['ffr', 'infl', 'unemp'] as k}<button class:on={imp === k} onclick={() => pick(k as VarKey)}>Shock {k === 'ffr' ? 'the funds rate' : META[k as VarKey].label.toLowerCase()}</button>{/each}
    </div>
    <button class="btn btn-ghost btn-sm" onclick={() => (playing ? pause() : play())}>{playing ? 'Pause' : t >= H ? 'Replay' : 'Play'}</button>
    <label class="sl">Quarter <input type="range" min="0" max={H} step="1" value={q} oninput={(e) => { pause(); t = +(e.target as HTMLInputElement).value; }} aria-valuetext={`${q} quarters after the shock`} /> <b>{q}</b></label>
  {/snippet}
  <div class="rip" bind:this={box}>
    <svg viewBox={`0 0 ${W} ${HH}`} class="net" role="img" aria-label={`Network of inflation, unemployment and the funds rate; ${META[imp].label} is shocked; quarter ${q}: ${KEYS.map((k) => `${META[k].label} ${sgn(at(k, t))} percentage points`).join(', ')}`}>
      <!-- edges: every variable feeds every other through lags -->
      {#each [['ffr', 'infl'], ['ffr', 'unemp'], ['infl', 'unemp']] as [a, b]}
        {@const act = a === imp || b === imp}
        {@const tgt = (a === imp ? b : a) as VarKey}
        <line x1={POS[a as VarKey][0]} y1={POS[a as VarKey][1]} x2={POS[b as VarKey][0]} y2={POS[b as VarKey][1]}
          stroke={act ? col(imp) : 'var(--border-strong)'} stroke-opacity={act ? 0.35 + 0.5 * Math.abs(at(tgt, t)) / maxAbs[tgt] : 0.6}
          stroke-width={act ? 1.5 + 6 * Math.abs(at(tgt, t)) / maxAbs[tgt] : 1.25} stroke-linecap="round" />
      {/each}
      <!-- pulses travelling from the shocked node, one per quarter -->
      {#if playing && !reduced()}
        {#each others as k}
          {@const [x0, y0] = POS[imp]}
          {@const [x1, y1] = POS[k]}
          <circle cx={x0 + (x1 - x0) * frac} cy={y0 + (y1 - y0) * frac} r={3 + 6 * Math.abs(at(k, t)) / maxAbs[k]} fill={col(imp)} opacity={0.9 - 0.5 * frac} />
        {/each}
        {@const [ax, ay] = POS[others[0]]}
        {@const [bx, by] = POS[others[1]]}
        <circle cx={ax + (bx - ax) * ((frac + 0.5) % 1)} cy={ay + (by - ay) * ((frac + 0.5) % 1)} r="2.6" fill="var(--muted)" opacity="0.6" />
        <circle cx={POS[imp][0]} cy={POS[imp][1]} r={R0 + 46 * frac} fill="none" stroke={col(imp)} stroke-width="2" opacity={(1 - frac) * (0.25 + 0.75 * Math.abs(at(imp, t)) / maxAbs[imp])} />
      {/if}
      {#each KEYS as k}
        {@const v = at(k, t)}
        {@const s = Math.abs(v) / Math.max(...KEYS.map((j) => maxAbs[j]))}
        {@const [cx, cy] = POS[k]}
        <g class="node" class:hit={k === imp}>
          <circle {cx} {cy} r={R0 + 4 + 34 * Math.min(1, Math.abs(v) / maxAbs[k]) * (0.35 + 0.65 * s)} fill="none" stroke={col(k)} stroke-width="2.2" stroke-dasharray={v < 0 ? '5 4' : null} opacity={Math.abs(v) < 0.005 ? 0 : 0.9} />
          <circle {cx} {cy} r={R0} fill="var(--surface-2)" stroke={col(k)} stroke-width={k === imp ? 3 : 2} />
          <text x={cx} y={cy - 3} text-anchor="middle" class="nv" fill="var(--text)">{sgn(v)}</text>
          <text x={cx} y={cy + 14} text-anchor="middle" class="nu">pp</text>
          <text x={cx} y={k === 'ffr' ? cy - R0 - 12 : cy + R0 + 22} text-anchor="middle" class="nl" fill={col(k)}>{META[k].label}{k === imp ? ' (shocked)' : ''}</text>
        </g>
      {/each}
      <text x="12" y={HH - 10} class="clock">Quarter {q}{q >= 4 ? ` · ${(q / 4).toFixed(q % 4 ? 2 : 0).replace(/\.?0+$/, '')} yr` : ''}</text>
    </svg>
    <div class="side">
      <div class="charts" bind:this={chartsEl}></div>
      <p class="story" aria-live="polite">{@html STORY[imp]}</p>
      <ul class="peaks">
        {#each others as k}<li><b style:color={col(k)}>{META[k].label}</b>: largest move {sgn(ir[k].pt[peak[k]])} pp, {yrs(peak[k])}</li>{/each}
      </ul>
    </div>
  </div>
</Explorable>
</div>

<style>
  .rip { display: grid; grid-template-columns: minmax(0, 0.9fr) minmax(0, 1.1fr); gap: 1.2rem; align-items: start; }
  @media (max-width: 760px) { .rip { grid-template-columns: 1fr; } }
  .net { width: 100%; height: auto; max-height: 360px; }
  .nv { font: 700 15px var(--font-ui); font-variant-numeric: tabular-nums; }
  .nu { font: 500 12px var(--font-ui); fill: var(--muted); }
  .nl { font: 650 13px var(--font-ui); }
  .clock { font: 600 12px var(--font-ui); fill: var(--muted); font-variant-numeric: tabular-nums; }
  .charts { display: flex; flex-direction: column; gap: 2px; min-height: 336px; }
  .story { font-size: .88rem; color: var(--text-2); margin: .5rem 0 .3rem; }
  .peaks { font-size: .82rem; color: var(--muted); margin: 0; padding-left: 1.1rem; font-variant-numeric: tabular-nums; }
</style>
