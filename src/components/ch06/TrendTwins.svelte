<script lang="ts">
  // Explorable: two unrelated trending series look "related" in levels; in growth rates the link disappears.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, ym, type Pt } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';

  const PAIRS = {
    food: { a: { id: 'CPIUFDSL', name: 'Food prices' }, b: { id: 'MRTSSM4541USS', name: 'E-commerce sales' } },
    iowa: { a: { id: 'IANA', name: 'Iowa jobs' }, b: { id: 'MRTSSM4541USS', name: 'E-commerce sales' } },
    money: { a: { id: 'CPIUFDSL', name: 'Food prices' }, b: { id: 'M2SL', name: 'Money supply (M2)' } },
  } as const;
  type K = keyof typeof PAIRS;
  const START = '2000-01-01', END = '2019-12-01';

  let pid: K = $state('food');
  let mode: 'level' | 'growth' = $state('level');
  let A: Pt[] = $state([]), B: Pt[] = $state([]);
  let tsEl: HTMLDivElement, scEl: HTMLDivElement, wrap: HTMLDivElement;

  async function load() {
    const p = PAIRS[pid];
    const [a, b] = await Promise.all([loadSeries(p.a.id, { start: START, end: END }), loadSeries(p.b.id, { start: START, end: END })]);
    // align on common dates
    const mb = new Map(b.data.map((q) => [+q.date, q.value]));
    const aa = a.data.filter((q) => mb.has(+q.date));
    A = aa; B = aa.map((q) => ({ date: q.date, value: mb.get(+q.date)! }));
  }
  $effect(() => { pid; load(); });

  // log levels, or monthly growth = 100 x change in log
  const tf = (x: Pt[]) => (mode === 'level' ? x.map((p) => ({ date: p.date, value: Math.log(p.value) }))
    : x.slice(1).map((p, i) => ({ date: p.date, value: 100 * (Math.log(p.value) - Math.log(x[i].value)) })));
  const xa = $derived(tf(A)), xb = $derived(tf(B));

  const stats = $derived.by(() => {
    const n = xa.length; if (n < 10) return null;
    const ya = xa.map((p) => p.value), yb = xb.map((p) => p.value);
    const ma = ya.reduce((s, v) => s + v, 0) / n, mb = yb.reduce((s, v) => s + v, 0) / n;
    let sab = 0, saa = 0, sbb = 0;
    for (let i = 0; i < n; i++) { sab += (ya[i] - ma) * (yb[i] - mb); saa += (ya[i] - ma) ** 2; sbb += (yb[i] - mb) ** 2; }
    const r = sab / Math.sqrt(saa * sbb), slope = sab / sbb;
    return { n, r, r2: r * r, t: r * Math.sqrt((n - 2) / (1 - r * r)), slope, icpt: ma - slope * mb, ma, mb, sa: Math.sqrt(saa / (n - 1)), sb: Math.sqrt(sbb / (n - 1)) };
  });

  function draw() {
    if (!tsEl || !scEl || !stats || tsEl.clientWidth < 120 || scEl.clientWidth < 120) return;
    const p = PAIRS[pid];
    const z = (x: Pt[], m: number, s: number, name: string) => x.map((q) => ({ date: q.date, z: (q.value - m) / s, raw: q.value, name }));
    const rows = [...z(xa, stats.ma, stats.sa, p.a.name), ...z(xb, stats.mb, stats.sb, p.b.name)];
    const lastA = rows.filter((r) => r.name === p.a.name).at(-1)!, lastB = rows.filter((r) => r.name === p.b.name).at(-1)!;
    const unit = mode === 'level' ? 'log level' : '% change from previous month';
    const W1 = tsEl.clientWidth;
    const c1 = Plot.plot({
      width: W1, height: 250, marginLeft: 40, marginRight: W1 < 480 ? 12 : 118, marginTop: 12, marginBottom: 28,
      style: plotStyle(), x: { label: null }, y: { label: 'standardized (z-score)', grid: true, ticks: 5 },
      marks: [
        Plot.ruleY([0], { stroke: C.borderStrong }),
        Plot.lineY(rows, { x: 'date', y: 'z', z: 'name', stroke: (r: any) => (r.name === p.a.name ? C.s[0] : C.s[1]), strokeWidth: mode === 'level' ? 2.2 : 1.25, strokeOpacity: mode === 'level' ? 1 : 0.8 }),
        ...(W1 >= 480 ? [
          Plot.text([lastA], { x: 'date', y: 'z', text: 'name', dx: 6, dy: lastA.z >= lastB.z ? -7 : 7, textAnchor: 'start', fill: C.s[0], fontSize: 12, fontWeight: 600 }),
          Plot.text([lastB], { x: 'date', y: 'z', text: 'name', dx: 6, dy: lastA.z >= lastB.z ? 7 : -7, textAnchor: 'start', fill: C.s[1], fontSize: 12, fontWeight: 600 }),
        ] : []),
        Plot.tip(rows, Plot.pointerX({ x: 'date', y: 'z', z: 'name', title: (r: any) => `${r.name}, ${ym(r.date)}\n${r.raw.toFixed(mode === 'level' ? 3 : 2)} (${unit})` })),
      ],
    });
    c1.setAttribute('aria-label', `${p.a.name} and ${p.b.name}, ${mode === 'level' ? 'log levels' : 'monthly growth rates'}, standardized, 2000 to 2019`);
    tsEl.replaceChildren(c1);

    const pts = xa.map((q, i) => ({ x: xb[i].value, y: q.value, date: q.date }));
    const xs = pts.map((q) => q.x), x0 = Math.min(...xs), x1 = Math.max(...xs);
    const c2 = Plot.plot({
      width: scEl.clientWidth, height: 250, marginLeft: 48, marginTop: 12, marginBottom: 36,
      style: plotStyle(), x: { label: `${p.b.name} (${mode === 'level' ? 'log' : '% m/m'})`, ticks: 4 }, y: { label: `${p.a.name} (${mode === 'level' ? 'log' : '% m/m'})`, grid: true, ticks: 5 },
      marks: [
        Plot.dot(pts, { x: 'x', y: 'y', r: 2.4, fill: C.history, fillOpacity: 0.45 }),
        Plot.line([{ x: x0, y: stats.icpt + stats.slope * x0 }, { x: x1, y: stats.icpt + stats.slope * x1 }], { x: 'x', y: 'y', stroke: C.forecast, strokeWidth: 2.5 }),
        Plot.tip(pts, Plot.pointer({ x: 'x', y: 'y', title: (q: any) => `${ym(q.date)}\n${p.b.name}: ${q.x.toFixed(mode === 'level' ? 3 : 2)}\n${p.a.name}: ${q.y.toFixed(mode === 'level' ? 3 : 2)}` })),
      ],
    });
    c2.setAttribute('aria-label', `Scatter of ${p.a.name} against ${p.b.name} with a fitted line; correlation ${stats.r.toFixed(2)}`);
    scEl.replaceChildren(c2);
  }

  let animate = false;
  function setMode(m: 'level' | 'growth') { if (m !== mode) { mode = m; animate = true; } }
  $effect(() => {
    xa; xb; stats; draw();
    if (animate && wrap && !matchMedia('(prefers-reduced-motion: reduce)').matches) wrap.animate([{ opacity: 0.3 }, { opacity: 1 }], { duration: 350, easing: 'cubic-bezier(0.2,0,0,1)' });
    animate = false;
  });
  onMount(() => { const offs = [tsEl, scEl].map((e) => watchLayout(e, draw)); return () => offs.forEach((f) => f()); });
</script>

<Explorable title="Two trends make a fake relationship; growth rates tell the truth" caption="Each pair of series has no economic link, but both rose from 2000 to 2019 (monthly, seasonally adjusted, ending before the pandemic). Left: both series on a common standardized scale. Right: one against the other, with the least-squares line. Switch to <b>growth rates</b> (100 × the monthly change in logs) and watch the correlation collapse. The levels regression was measuring two trends, not a link.">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Pair of series">
      {#each Object.entries(PAIRS) as [k, v]}<button class:on={pid === k} aria-pressed={pid === k} onclick={() => (pid = k as K)}>{v.a.name} vs {v.b.name}</button>{/each}
    </div>
    <div class="seg" role="group" aria-label="Transformation">
      <button class:on={mode === 'level'} aria-pressed={mode === 'level'} onclick={() => setMode('level')}>Levels (logs)</button>
      <button class:on={mode === 'growth'} aria-pressed={mode === 'growth'} onclick={() => setMode('growth')}>Growth rates</button>
    </div>
  {/snippet}
  <div class="pair" bind:this={wrap}>
    <div>
      <div class="key" aria-hidden="true"><span class="sw a"></span>{PAIRS[pid].a.name}<span class="sw b"></span>{PAIRS[pid].b.name}</div>
      <div bind:this={tsEl} class="c"></div>
    </div>
    <div bind:this={scEl} class="c"></div>
  </div>
  {#if stats}
    <div class="row" aria-live="polite">
      <div class="stat"><span class="stat-v">{stats.r.toFixed(2)}</span><span class="stat-l">correlation</span></div>
      <div class="stat"><span class="stat-v">{stats.r2.toFixed(2)}</span><span class="stat-l">R² of the regression</span></div>
      <div class="stat"><span class="stat-v">{stats.t.toFixed(1)}</span><span class="stat-l">t-statistic of the slope (|t| &gt; 2 looks "significant")</span></div>
      <p class="verdict {Math.abs(stats.t) > 2 ? 'warn' : 'good'}">
        {#if mode === 'level'}In levels, {Math.round(stats.r2 * 100)}% of the variation is "explained" and t = {stats.t.toFixed(0)}. Nothing links these series except that both grew. Shared trends, not shared movements, produce this.
        {:else if Math.abs(stats.t) > 2}In growth rates the correlation is {stats.r.toFixed(2)}: small, but the t-statistic still clears 2. A weak link like this could be real or chance; it is nothing like the levels picture.
        {:else}In growth rates the correlation is {stats.r.toFixed(2)} and t = {stats.t.toFixed(1)}: no relationship at all. When one series grows faster than usual, the other does not.{/if}
      </p>
    </div>
  {/if}
</Explorable>

<style>
  .pair { display: grid; grid-template-columns: minmax(0, 1.3fr) minmax(0, 1fr); gap: 1.2rem; }
  @media (max-width: 760px) { .pair { grid-template-columns: 1fr; } }
  .c { min-height: 250px; }
  .key { display: none; align-items: center; gap: .35rem; font-size: .8rem; color: var(--text-2); margin-bottom: .2rem; }
  .sw { width: 14px; height: 3px; border-radius: 2px; display: inline-block; margin-left: .5rem; }
  .sw:first-child { margin-left: 0; }
  .sw.a { background: var(--c-s1); } .sw.b { background: var(--c-s2); }
  @media (max-width: 560px) { .key { display: flex; flex-wrap: wrap; } }
  .row { display: flex; flex-wrap: wrap; gap: .8rem 1.8rem; align-items: flex-start; margin-top: .8rem; }
  .verdict { flex: 1 1 260px; margin: 0; padding: .55rem .8rem; border-radius: 8px; border: 1px solid var(--border); font-size: .88rem; color: var(--text); line-height: 1.5; }
  .verdict.warn { border-color: color-mix(in srgb, var(--danger) 50%, transparent); }
  .verdict.good { border-color: color-mix(in srgb, var(--good) 50%, transparent); }
</style>
