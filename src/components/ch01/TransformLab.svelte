<script lang="ts">
  // Transformation lab: one real series, six standard views. The line morphs between views so
  // students see each transformation as an operation on the same data, not as a new chart.
  import { onMount } from 'svelte';
  import * as d3 from 'd3';
  import 'd3-transition'; // side-effect import: keeps selection.transition() in production builds
  import Explorable from '../Explorable.svelte';
    import { C, watchLayout } from '../../lib/viz/theme';
  import { loadPublished, monthLabel, signed, reducedMotion, avg, mkey, type GridPt } from './util';

  type View = 'level' | 'log' | 'mom' | 'yoy' | 'ann' | 'idx';
  type Sid = 'RSXFSN' | 'CPIAUCSL';
  const SERIES: Record<Sid, { label: string; unit: string; name: string }> = {
    RSXFSN: { label: 'Retail sales (NSA)', unit: '$ millions, not seasonally adjusted', name: 'Retail sales' },
    CPIAUCSL: { label: 'Consumer prices (SA)', unit: 'index, 1982–84 = 100, seasonally adjusted', name: 'CPI' },
  };
  const VIEWS: { k: View; label: string; axis: string }[] = [
    { k: 'level', label: 'Level', axis: '' },
    { k: 'log', label: 'Log', axis: 'natural log of level' },
    { k: 'mom', label: 'MoM %', axis: '% change from previous month' },
    { k: 'yoy', label: 'YoY %', axis: '% change from a year earlier' },
    { k: 'ann', label: 'Annualized', axis: 'monthly change, annualized %' },
    { k: 'idx', label: 'Index 2019 = 100', axis: 'index, 2019 average = 100' },
  ];
  // Which point to annotate in each view (falls back to the extreme in the visible window).
  const FEATURE: Record<Sid, Record<View, string>> = {
    RSXFSN: { level: '2025-12', log: 'last', mom: '2026-01', yoy: '2020-04', ann: '2025-12', idx: 'last' },
    CPIAUCSL: { level: 'last', log: 'last', mom: 'max', yoy: 'max', ann: 'max', idx: 'last' },
  };
  const NOTES: Record<View, { what: string; retail: string; cpi: string }> = {
    level: { what: 'The raw numbers. Answers “how big is it?”', retail: 'The upward trend is buried under a spike every December and a drop every January. Hard to read growth off this chart.', cpi: 'Prices rise almost every month, so the line climbs steadily. Notice it gets steeper in 2021–22.' },
    log: { what: 'The natural log of the level. Constant percentage growth becomes a straight line, so a change in slope is a change in the growth rate. A rise of 0.01 is about 1%.', retail: 'The trend is now close to a straight line: retail sales grow at a fairly steady percentage rate. The seasonal spikes look the same size in every year.', cpi: 'Almost straight from 2000 to 2020 (about 2% a year), then a visible kink upward: the 2021–22 inflation surge.' },
    mom: { what: 'Percent change from the previous month. Timely, but noisy.', retail: 'This is mostly the calendar, not the economy: up sharply every December, down sharply every January. Never read MoM growth off NSA data.', cpi: 'Because CPI is seasonally adjusted, MoM is meaningful here, but one month is noisy. Analysts look at several months in a row.' },
    yoy: { what: 'Percent change from the same month a year earlier. Comparing like with like cancels the seasonal pattern.', retail: 'The December spikes are gone. What remains is the business cycle: the COVID collapse in April 2020, the 2021 rebound, then steadier growth.', cpi: 'This is the inflation rate you hear in the news. It peaked in June 2022. The two small gaps (October 2025 and October 2026) both trace back to the one month BLS never published. This chart shows the data as published; fred() would fill the gap by interpolation.' },
    ann: { what: 'One month’s growth compounded over a year: (x<sub>t</sub>/x<sub>t−1</sub>)<sup>12</sup> − 1. Puts monthly changes on the yearly scale of GDP and Fed headlines.', retail: 'Absurd on NSA data: it claims sales are on pace to triple or quadruple every December. Annualize only seasonally adjusted series.', cpi: 'Valid for SA data, but compounding multiplies the noise: a single 0.5% month reads as about 6% annualized.' },
    idx: { what: 'Divide by the 2019 average and multiply by 100. Units disappear: 140 means 40% above the 2019 level.', retail: 'Same shape as the level, now in “percent of 2019”. Useful for comparing series measured in different units.', cpi: 'Read the latest value as “prices are this many percent above their 2019 average”.' },
  };

  let sid: Sid = $state('RSXFSN');
  let view: View = $state('level');
  let range: 'all' | '5y' = $state('all');
  let grids: Partial<Record<Sid, GridPt[]>> = $state({});
  let el: HTMLDivElement;
  let hover: number | null = $state(null);

  onMount(() => {
    Promise.all((['RSXFSN', 'CPIAUCSL'] as Sid[]).map((id) => loadPublished(id).then((g) => [id, g] as const))).then((r) => {
      grids = Object.fromEntries(r);
    });
    build();
    return watchLayout(el, () => build());
  });

  function transform(g: GridPt[], v: View): number[] {
    const base = avg(g.filter((p) => p.date.getFullYear() === 2019).map((p) => p.value));
    return g.map((p, i) => {
      const x = p.value, x1 = g[i - 1]?.value ?? NaN, x12 = g[i - 12]?.value ?? NaN;
      switch (v) {
        case 'level': return x;
        case 'log': return Math.log(x);
        case 'mom': return 100 * (x / x1 - 1);
        case 'yoy': return 100 * (x / x12 - 1);
        case 'ann': return 100 * ((x / x1) ** 12 - 1);
        case 'idx': return (100 * x) / base;
      }
    });
  }

  const rows = $derived.by(() => {
    const g = grids[sid];
    if (!g) return null;
    const y = transform(g, view);
    let pts = g.map((p, i) => ({ date: p.date, y: y[i] }));
    pts = pts.filter((p) => p.date.getFullYear() >= 2000);
    if (range === '5y') pts = pts.slice(-60);
    return pts;
  });

  const featured = $derived.by(() => {
    if (!rows) return -1;
    const f = FEATURE[sid][view];
    const fin = rows.map((p, i) => [p.y, i] as const).filter(([v]) => Number.isFinite(v));
    if (!fin.length) return -1;
    if (f === 'last') return fin[fin.length - 1][1];
    if (f === 'max') return fin.reduce((a, b) => (b[0] > a[0] ? b : a))[1];
    const i = rows.findIndex((p) => mkey(p.date) === f);
    if (i >= 0 && Number.isFinite(rows[i].y)) return i;
    // requested date not visible: annotate the largest move (% views) or the latest value (level views)
    if (view === 'mom' || view === 'yoy' || view === 'ann') return fin.reduce((a, b) => (Math.abs(b[0]) > Math.abs(a[0]) ? b : a))[1];
    return fin[fin.length - 1][1];
  });

  const latest = $derived.by(() => {
    if (!rows) return null;
    for (let i = rows.length - 1; i >= 0; i--) if (Number.isFinite(rows[i].y)) return rows[i];
    return null;
  });

  function fmtV(v: number, k: View = view, s: Sid = sid): string {
    if (!Number.isFinite(v)) return 'not available';
    if (k === 'level') return s === 'RSXFSN' ? `$${Math.round(v / 1000).toLocaleString('en-US')} billion` : v.toFixed(1);
    if (k === 'log') return v.toFixed(3);
    if (k === 'idx') return v.toFixed(1);
    return `${signed(v, 1)}%`;
  }
  const tick = (v: number) => (view === 'level' && sid === 'RSXFSN' ? `$${d3.format(',')(v / 1000)}bn` : view === 'log' ? v.toFixed(2) : view === 'level' || view === 'idx' ? d3.format(',')(v) : `${v}%`);

  // ── D3 drawing with morphing ─────────────────────────────
  let svg: d3.Selection<SVGSVGElement, unknown, null, undefined> | null = null;
  let prevKey = '';
  let prevPix: number[] = [];
  const M = { t: 18, r: 18, b: 30, l: 62 };
  let W = 600, H = 360;

  function build() {
    if (!el) return;
    W = el.clientWidth || 600; H = Math.max(300, Math.min(400, W * 0.5));
    el.replaceChildren();
    svg = d3.select(el).append('svg').attr('width', W).attr('height', H).attr('role', 'img').attr('tabindex', 0);
    svg.append('g').attr('class', 'gy');
    svg.append('g').attr('class', 'gx').attr('transform', `translate(0,${H - M.b})`);
    svg.append('line').attr('class', 'zero');
    svg.append('path').attr('class', 'ln').attr('fill', 'none').attr('stroke-width', 2.2).attr('stroke-linejoin', 'round');
    svg.append('g').attr('class', 'feat');
    svg.append('g').attr('class', 'hov');
    svg.append('rect').attr('class', 'ov').attr('x', M.l).attr('y', M.t).attr('width', W - M.l - M.r).attr('height', H - M.t - M.b).attr('fill', 'transparent')
      .on('pointermove', (e: PointerEvent) => { const [mx] = d3.pointer(e); hover = nearest(mx); })
      .on('pointerleave', () => (hover = null));
    svg.on('keydown', (e: KeyboardEvent) => {
      if (!rows) return;
      if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') { e.preventDefault(); const h = hover ?? rows.length - 1; hover = Math.max(0, Math.min(rows.length - 1, h + (e.key === 'ArrowLeft' ? -1 : 1))); }
      if (e.key === 'Escape') hover = null;
    });
    prevKey = ''; prevPix = [];
    draw(false);
  }

  let xs: d3.ScaleTime<number, number> | null = null;
  function nearest(mx: number) {
    if (!rows || !xs) return null;
    const t = xs.invert(mx);
    const i = d3.bisector((p: { date: Date }) => p.date).center(rows, t);
    return Math.max(0, Math.min(rows.length - 1, i));
  }

  function draw(animate = true) {
    if (!svg || !rows) return;
    const dur = animate && !reducedMotion() ? 420 : 0;
    const x = d3.scaleTime().domain(d3.extent(rows, (p) => p.date) as [Date, Date]).range([M.l, W - M.r]);
    xs = x;
    const fin = rows.map((p) => p.y).filter(Number.isFinite);
    const pct = view === 'mom' || view === 'yoy' || view === 'ann';
    let [lo, hi] = d3.extent(fin) as [number, number];
    if (pct) { lo = Math.min(lo, 0); hi = Math.max(hi, 0); }
    const y = d3.scaleLinear().domain([lo, hi]).nice(6).range([H - M.b, M.t]);
    const pix = rows.map((p) => (Number.isFinite(p.y) ? y(p.y) : NaN));
    const key = `${sid}|${range}`;
    const morph = dur > 0 && key === prevKey && prevPix.length === pix.length;
    const old = morph ? prevPix.slice() : pix;
    prevKey = key; prevPix = pix;

    svg.attr('aria-label', `${SERIES[sid].name}, ${VIEWS.find((v) => v.k === view)!.label} view, ${monthLabel(rows[0].date)} to ${monthLabel(rows[rows.length - 1].date)}. Latest: ${latest ? fmtV(latest.y) : ''}.`);
    const t = svg.transition().duration(dur).ease(d3.easeCubicOut) as any;

    const gy = svg.select<SVGGElement>('.gy');
    gy.transition(t).call(d3.axisLeft(y).ticks(6).tickSize(-(W - M.l - M.r)).tickFormat((v) => tick(+v)) as any)
      .attr('transform', `translate(${M.l},0)`);
    gy.call((g) => { g.select('.domain').remove(); g.selectAll('line').attr('stroke', C.border); g.selectAll('text').attr('fill', C.muted).attr('font-size', 12).attr('x', -6); });
    const gx = svg.select<SVGGElement>('.gx');
    gx.call(d3.axisBottom(x).ticks(Math.max(3, Math.floor(W / 110))).tickSizeOuter(0) as any);
    gx.call((g) => { g.select('.domain').attr('stroke', C.borderStrong); g.selectAll('line').attr('stroke', C.borderStrong); g.selectAll('text').attr('fill', C.muted).attr('font-size', 12); });

    svg.select('.zero').attr('x1', M.l).attr('x2', W - M.r).attr('stroke', C.text2).attr('stroke-width', 1.5)
      .transition(t).attr('y1', y(0)).attr('y2', y(0)).attr('opacity', pct ? 0.8 : 0);

    const line = d3.line<number>().defined((v) => Number.isFinite(v)).x((_, i) => x(rows[i].date)).y((v) => v);
    const path = svg.select<SVGPathElement>('.ln').attr('stroke', C.fitted);
    if (morph) {
      path.transition(t).attrTween('d', () => (u: number) => line(old.map((o, i) => (Number.isFinite(o) && Number.isFinite(pix[i]) ? o + (pix[i] - o) * u : NaN))) ?? '');
    } else {
      path.interrupt().attr('d', line(pix) ?? '');
    }

    // annotation for the featured point
    const fg = svg.select<SVGGElement>('.feat');
    fg.selectAll('*').remove();
    if (featured >= 0) {
      const p = rows[featured];
      const fx = x(p.date), fy = y(p.y);
      const left = fx > W * 0.62;
      const ty = Math.max(M.t + 14, Math.min(H - M.b - 8, fy + (fy < H / 2 ? 22 : -14)));
      const g = fg.append('g').attr('opacity', 0);
      g.append('circle').attr('cx', fx).attr('cy', fy).attr('r', 4.5).attr('fill', C.actual).attr('stroke', C.surface).attr('stroke-width', 2);
      g.append('text').attr('x', fx + (left ? -9 : 9)).attr('y', ty).attr('text-anchor', left ? 'end' : 'start')
        .attr('fill', C.text).attr('font-size', 13).attr('font-weight', 650).attr('stroke', C.surface).attr('stroke-width', 3).attr('paint-order', 'stroke')
        .text(`${monthLabel(p.date)}: ${fmtV(p.y)}`);
      g.transition().delay(dur * 0.7).duration(dur ? 200 : 0).attr('opacity', 1);
    }
    drawHover();
  }

  function drawHover() {
    if (!svg || !rows || !xs) return;
    const hg = svg.select<SVGGElement>('.hov');
    hg.selectAll('*').remove();
    if (hover === null || !rows[hover]) return;
    const p = rows[hover];
    const px = xs(p.date);
    hg.append('line').attr('x1', px).attr('x2', px).attr('y1', M.t).attr('y2', H - M.b).attr('stroke', C.borderStrong);
    const yv = prevPix[hover];
    if (Number.isFinite(yv)) hg.append('circle').attr('cx', px).attr('cy', yv).attr('r', 4).attr('fill', C.fitted);
  }

  $effect(() => { rows; featured; if (svg) draw(true); });
  $effect(() => { hover; drawHover(); });

  const vInfo = $derived(VIEWS.find((v) => v.k === view)!);
  const note = $derived(NOTES[view]);
  const readout = $derived(hover !== null && rows?.[hover] ? rows[hover] : latest);
</script>

<Explorable title="Same data, six stories: switch the view and watch the line change" caption={`Switch the <b>view</b> to transform the same monthly series. The line morphs, so you can follow each month from one view to the next. Hover over the chart, or focus it and use the arrow keys, to read any month. The gold dot marks the month each view makes most striking. Data: FRED (${sid}), ${SERIES[sid].unit}.`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Series">
      {#each Object.entries(SERIES) as [k, s]}<button class:on={sid === k} aria-pressed={sid === k} onclick={() => (sid = k as Sid)}>{s.label}</button>{/each}
    </div>
    <div class="seg" role="group" aria-label="Transformation">
      {#each VIEWS as v}<button class:on={view === v.k} aria-pressed={view === v.k} onclick={() => (view = v.k)}>{v.label}</button>{/each}
    </div>
    <div class="seg" role="group" aria-label="Time range">
      <button class:on={range === 'all'} aria-pressed={range === 'all'} onclick={() => (range = 'all')}>Since 2000</button>
      <button class:on={range === '5y'} aria-pressed={range === '5y'} onclick={() => (range = '5y')}>Last 5 years</button>
    </div>
  {/snippet}
  {#snippet aside()}
    <div class="note" aria-live="polite">
      <div class="axis">{view === 'level' ? SERIES[sid].unit : vInfo.axis}</div>
      {#if readout}
        <div class="stat"><span class="stat-v">{fmtV(readout.y)}</span><span class="stat-l">{hover !== null ? '' : 'Latest: '}{monthLabel(readout.date)}</span></div>
      {/if}
      <p class="what">{@html note.what}</p>
      <p class="reveal"><b>{sid === 'RSXFSN' ? 'Retail sales:' : 'CPI:'}</b> {sid === 'RSXFSN' ? note.retail : note.cpi}</p>
    </div>
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 300px; }
  .chart :global(svg:focus-visible) { outline: 2px solid var(--accent-2); outline-offset: 4px; border-radius: 6px; }
  .note { font-size: .86rem; line-height: 1.55; }
  .axis { font-size: .76rem; color: var(--muted); margin-bottom: .5rem; }
  .what { color: var(--text); margin: .8rem 0 .5rem; }
  .reveal { color: var(--text-2); margin: 0; }
  .stat-v { color: var(--c-fitted); }
</style>
