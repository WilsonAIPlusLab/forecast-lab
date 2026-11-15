<script lang="ts" module>
  export interface DecompModel {
    dates: Date[]; data: number[]; trend: number[]; seasonal: number[]; remainder: number[]; official: (number | null)[];
  }
  // One entry per scrolly step: the layout and the opacity of each layer.
  export const STEPS: { layout: 'big' | 'rows'; show: Partial<Record<'data' | 'trend' | 'seas' | 'rem' | 'sa' | 'off', number>>; ann: string }[] = [
    { layout: 'big', show: { data: 1 }, ann: 'intro' },
    { layout: 'big', show: { data: 1 }, ann: 'dec' },
    { layout: 'big', show: { data: 0.35, trend: 1 }, ann: 'trend' },
    { layout: 'rows', show: { trend: 1, seas: 1, rem: 1 }, ann: 'split' },
    { layout: 'rows', show: { trend: 0.22, seas: 1, rem: 0.22 }, ann: 'seas' },
    { layout: 'rows', show: { trend: 0.22, seas: 0.22, rem: 1 }, ann: 'rem' },
    { layout: 'big', show: { trend: 1, seas: 1, rem: 1 }, ann: 'recombine' },
    { layout: 'big', show: { data: 0.3, sa: 1, off: 1 }, ann: 'sa' },
  ];
</script>

<script lang="ts">
  // @ts-ignore: d3 ships without type declarations in this project
  import { scaleLinear, scaleTime, easeCubicOut } from 'd3';
  import { onMount, untrack } from 'svelte';
  interface Props { model: DecompModel; step: number; animate?: boolean; label?: string }
  let { model, step, animate = true, label = '' }: Props = $props();

  let W = $state(720);
  const H = $derived(Math.round(Math.max(360, Math.min(520, W * 0.66))));
  const M = $derived({ l: W < 520 ? 44 : 58, r: W < 520 ? 12 : 128, t: 22, b: 30 });
  const narrow = $derived(W < 520);
  let reduced = false;
  onMount(() => { reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches; });

  const keys = ['data', 'trend', 'seas', 'rem', 'sa', 'off'] as const;
  type K = (typeof keys)[number];
  const pct = (v: number) => 100 * (Math.exp(v) - 1);

  const geo = $derived.by(() => {
    const { dates, data, trend, seasonal, remainder, official } = model;
    const x = scaleTime().domain([dates[0], dates[dates.length - 1]]).range([M.l, W - M.r]);
    const top = M.t, bot = H - M.b, avail = bot - top, gap = 26;
    const h1 = (avail - 2 * gap) * 0.4, h2 = (avail - 2 * gap) * 0.3;
    const rows = [[top, top + h1], [top + h1 + gap, top + h1 + gap + h2], [top + h1 + 2 * gap + h2, bot]];
    const bn = (v: number) => v / 1000;
    const sa = data.map((v, i) => v / Math.exp(seasonal[i]));
    const all = [...data, ...sa, ...(official.filter((v) => v != null) as number[])].map(bn);
    const yBig = scaleLinear().domain([Math.min(...all) * 0.97, Math.max(...all) * 1.02]).range([bot, top]).nice();
    const tb = trend.map(bn);
    const yT = scaleLinear().domain([Math.min(...tb), Math.max(...tb)]).range([rows[0][1], rows[0][0]]);
    const sp = seasonal.map(pct), rp = remainder.map(pct);
    const smax = Math.max(...sp.map(Math.abs));
    const yS = scaleLinear().domain([-smax, smax]).range([rows[1][1], rows[1][0]]);
    const yR = scaleLinear().domain([Math.min(...rp), Math.max(...rp, 5)]).range([rows[2][1], rows[2][0]]);
    const big: Record<K, number[]> = {
      data: data.map((v) => yBig(bn(v))),
      trend: tb.map((v) => yBig(v)),
      seas: trend.map((t, i) => yBig(bn(t * Math.exp(seasonal[i])))),
      rem: data.map((v) => yBig(bn(v))),
      sa: sa.map((v) => yBig(bn(v))),
      off: official.map((v) => (v == null ? NaN : yBig(bn(v)))),
    };
    const rowsY: Record<K, number[]> = { ...big, trend: tb.map((v) => yT(v)), seas: sp.map((v) => yS(v)), rem: rp.map((v) => yR(v)) };
    return { x, xs: dates.map((d) => x(d)), yBig, yT, yS, yR, rows, big, rowsY, sp, rp, sa, top, bot };
  });

  // animated pixel arrays
  let cur: Record<K, number[]> | null = $state(null);
  let raf = 0, lastLayout = '', lastW = 0;
  $effect(() => {
    const g = geo; const s = STEPS[Math.max(0, Math.min(STEPS.length - 1, step))];
    const target = s.layout === 'big' ? g.big : g.rowsY;
    const w = W, prev = untrack(() => cur);
    const instant = !animate || reduced || !prev || lastW !== w || lastLayout === '' || lastLayout === s.layout;
    lastW = w; lastLayout = s.layout;
    cancelAnimationFrame(raf);
    if (instant) { cur = target; return; }
    const from = prev!; const t0 = performance.now(), dur = 650;
    const tick = (now: number) => {
      const k = Math.min(1, (now - t0) / dur), e = easeCubicOut(k);
      const nx = {} as Record<K, number[]>;
      for (const key of keys) nx[key] = target[key].map((v, i) => { const a = from[key][i]; return Number.isFinite(a) && Number.isFinite(v) ? a + (v - a) * e : v; });
      cur = nx;
      if (k < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
  });

  const path = (ys: number[] | undefined) => {
    if (!ys) return '';
    let d = '', pen = false;
    ys.forEach((y, i) => { if (!Number.isFinite(y)) { pen = false; return; } d += `${pen ? 'L' : 'M'}${geo.xs[i].toFixed(1)},${y.toFixed(1)}`; pen = true; });
    return d;
  };

  const st = $derived(STEPS[Math.max(0, Math.min(STEPS.length - 1, step))]);
  const op = (k: K) => st.show[k] ?? 0;
  const idx = (y: number, m: number) => model.dates.findIndex((d) => d.getFullYear() === y && d.getMonth() === m);
  const last = $derived(model.dates.length - 1);
  const decIdx = $derived(model.dates.map((d, i) => (d.getMonth() === 11 ? i : -1)).filter((i) => i >= 0));
  const lastDec = $derived(decIdx[decIdx.length - 1]);
  const f1 = (v: number) => (v > 0 ? '+' : v < 0 ? '−' : '') + Math.abs(v).toFixed(1) + '%';
  const yearTicks = $derived(geo.x.ticks(narrow ? 4 : 7));
  const endY = (k: K) => { const a = cur?.[k]; if (!a) return 0; for (let i = a.length - 1; i >= 0; i--) if (Number.isFinite(a[i])) return a[i]; return 0; };
  const LABELS: [K, string, string][] = [['data', 'Raw data (NSA)', 'var(--c-history)'], ['rem', 'Data (all three)', 'var(--c-s2)'], ['seas', 'Trend × seasonal', 'var(--c-s3)'], ['trend', 'Trend', 'var(--c-s1)'], ['sa', 'Our adjustment', 'var(--c-fitted)'], ['off', 'Census SA (X-13)', 'var(--c-actual)']];
  const endLabels = $derived.by(() => {
    if (!cur) return [];
    const ls = LABELS.filter(([k]) => op(k) >= 0.9).map(([k, txt, c]) => ({ txt, c, y: endY(k) })).sort((a, b) => a.y - b.y);
    for (let i = 1; i < ls.length; i++) if (ls[i].y - ls[i - 1].y < 15) ls[i].y = ls[i - 1].y + 15;
    return ls;
  });
  const iApr20 = $derived(idx(2020, 3)), iMar21 = $derived(idx(2021, 2)), iFeb25 = $derived(idx(2025, 1));
  const nsaJump = $derived(lastDec > 0 ? 100 * (model.data[lastDec] / model.data[lastDec - 1] - 1) : 0);
  const saJump = $derived(lastDec > 0 ? 100 * (geo.sa[lastDec] / geo.sa[lastDec - 1] - 1) : 0);
  const offJump = $derived(lastDec > 0 && model.official[lastDec] != null ? 100 * ((model.official[lastDec] as number) / (model.official[lastDec - 1] as number) - 1) : NaN);
</script>

<div class="df" bind:clientWidth={W}>
  <svg width={W} height={H} viewBox={`0 0 ${W} ${H}`} role="img" aria-label={label}>
    <!-- axes: big layout -->
    <g class="ax" style:opacity={st.layout === 'big' ? 1 : 0}>
      {#each geo.yBig.ticks(5) as t}
        <line x1={M.l} x2={W - M.r} y1={geo.yBig(t)} y2={geo.yBig(t)} class="grid" />
        <text x={M.l - 8} y={geo.yBig(t)} dy="0.32em" text-anchor="end">${t}bn</text>
      {/each}
    </g>
    <!-- axes: three rows -->
    <g class="ax" style:opacity={st.layout === 'rows' ? 1 : 0}>
      {#each [[geo.yT, 'bn'], [geo.yS, '%'], [geo.yR, '%']] as [sc, u], r}
        {#each (sc as any).ticks(3) as t}
          <line x1={M.l} x2={W - M.r} y1={(sc as any)(t)} y2={(sc as any)(t)} class:zero={u === '%' && t === 0} class="grid" />
          <text x={M.l - 8} y={(sc as any)(t)} dy="0.32em" text-anchor="end">{u === 'bn' ? `$${t}bn` : `${t > 0 ? '+' : ''}${t}%`}</text>
        {/each}
        {#if !narrow}
          <text class="rowlab" x={W - M.r + 10} y={geo.rows[r][0] + 12} style:fill={['var(--c-s1)', 'var(--c-s3)', 'var(--c-s2)'][r]}>{['Trend', 'Seasonal', 'Remainder'][r]}</text>
          <text class="rowsub" x={W - M.r + 10} y={geo.rows[r][0] + 28}>{['$ billions', '% vs trend', '% vs trend × seasonal'][r]}</text>
        {:else}
          <text class="rowlab" x={M.l + 4} y={geo.rows[r][0] + 10} style:fill={['var(--c-s1)', 'var(--c-s3)', 'var(--c-s2)'][r]}>{['Trend ($bn)', 'Seasonal (%)', 'Remainder (%)'][r]}</text>
        {/if}
      {/each}
    </g>
    {#each yearTicks as t}
      <text class="xt" x={geo.x(t)} y={H - 8} text-anchor="middle">{t.getFullYear()}</text>
    {/each}

    {#if cur}
      <path d={path(cur.data)} class="ln" style:stroke="var(--c-history)" style:stroke-width="2" style:opacity={op('data')} />
      <path d={path(cur.off)} class="ln" style:stroke="var(--c-actual)" style:stroke-width="2.2" stroke-dasharray="5 4" style:opacity={op('off')} />
      <path d={path(cur.sa)} class="ln" style:stroke="var(--c-fitted)" style:stroke-width="2.6" style:opacity={op('sa')} />
      <path d={path(cur.rem)} class="ln" style:stroke="var(--c-s2)" style:stroke-width={st.ann === 'rem' ? 2.6 : 1.8} style:opacity={op('rem')} />
      <path d={path(cur.seas)} class="ln" style:stroke="var(--c-s3)" style:stroke-width={st.ann === 'seas' ? 2.6 : 1.8} style:opacity={op('seas')} />
      <path d={path(cur.trend)} class="ln" style:stroke="var(--c-s1)" style:stroke-width="2.8" style:opacity={op('trend')} />

      <!-- end labels in the single-panel layout (nudged apart so they never overlap) -->
      {#if st.layout === 'big' && !narrow}
        {#each endLabels as l}
          <text class="end" x={W - M.r + 8} y={l.y} dy="0.32em" style:fill={l.c}>{l.txt}</text>
        {/each}
      {/if}

      <!-- step annotations -->
      {#if st.ann === 'dec'}
        {#each decIdx as i}<circle cx={geo.xs[i]} cy={cur.data[i]} r="4.5" class="dot" style:fill="var(--c-actual)" />{/each}
        <text class="ann" x={geo.xs[lastDec] - 8} y={cur.data[lastDec] - 12} text-anchor="end">Dec {model.dates[lastDec].getFullYear()}: {f1(nsaJump)} vs Nov</text>
      {/if}
      {#if st.ann === 'seas' && lastDec > 0}
        <circle cx={geo.xs[lastDec]} cy={cur.seas[lastDec]} r="4.5" class="dot" style:fill="var(--c-s3)" />
        <text class="ann" x={geo.xs[lastDec] - 8} y={cur.seas[lastDec] + 4} text-anchor="end">Dec: {f1(geo.sp[lastDec])}</text>
        {#if iFeb25 > 0}<circle cx={geo.xs[iFeb25]} cy={cur.seas[iFeb25]} r="4.5" class="dot" style:fill="var(--c-s3)" />
        <text class="ann" x={geo.xs[iFeb25] - 8} y={cur.seas[iFeb25] + 4} text-anchor="end">Feb: {f1(geo.sp[iFeb25])}</text>{/if}
      {/if}
      {#if st.ann === 'rem' && iApr20 > 0}
        <circle cx={geo.xs[iApr20]} cy={cur.rem[iApr20]} r="4.5" class="dot" style:fill="var(--c-s2)" />
        <text class="ann" x={geo.xs[iApr20] + 9} y={cur.rem[iApr20] + 4}>Apr 2020 lockdowns: {f1(geo.rp[iApr20])}</text>
        {#if iMar21 > 0}<circle cx={geo.xs[iMar21]} cy={cur.rem[iMar21]} r="4.5" class="dot" style:fill="var(--c-s2)" />
        <text class="ann" x={geo.xs[iMar21] + 9} y={cur.rem[iMar21] + 2}>Mar 2021 stimulus: {f1(geo.rp[iMar21])}</text>{/if}
      {/if}
      {#if st.ann === 'sa' && lastDec > 0}
        <circle cx={geo.xs[lastDec]} cy={cur.sa[lastDec]} r="4.5" class="dot" style:fill="var(--c-fitted)" />
        <text class="ann" x={geo.xs[lastDec] - 8} y={cur.sa[lastDec] - 26} text-anchor="end">Dec {model.dates[lastDec].getFullYear()} adjusted: {f1(saJump)} vs Nov</text>
        {#if Number.isFinite(offJump)}<text class="ann sub" x={geo.xs[lastDec] - 8} y={cur.sa[lastDec] - 10} text-anchor="end">Census: {f1(offJump)} · raw: {f1(nsaJump)}</text>{/if}
      {/if}
    {/if}
  </svg>
</div>

<style>
  .df { width: 100%; }
  svg { display: block; overflow: visible; font-family: var(--font-ui); }
  .ln { fill: none; stroke-linejoin: round; stroke-linecap: round; transition: opacity 400ms cubic-bezier(0.2, 0, 0, 1); }
  .ax { transition: opacity 400ms cubic-bezier(0.2, 0, 0, 1); }
  .ax text, .xt { font-size: 12px; fill: var(--muted); font-variant-numeric: tabular-nums; }
  .grid { stroke: var(--border); stroke-width: 1; }
  .grid.zero { stroke: var(--border-strong); stroke-width: 1.5; }
  .rowlab { font-size: 13px; font-weight: 700; }
  .rowsub { font-size: 12px; fill: var(--muted) !important; }
  .end { font-size: 12.5px; font-weight: 650; paint-order: stroke; stroke: var(--surface); stroke-width: 3px; }
  .ann { font-size: 13px; font-weight: 650; fill: var(--text); paint-order: stroke; stroke: var(--surface); stroke-width: 4px; }
  .ann.sub { font-weight: 500; fill: var(--text-2); font-size: 12px; }
  .dot { stroke: var(--surface); stroke-width: 1.5; }
  @media (prefers-reduced-motion: reduce) { .ln, .ax { transition: none; } }
</style>
