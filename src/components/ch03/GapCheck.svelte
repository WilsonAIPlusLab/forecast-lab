<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, fcNaive, fcDrift, mean, ym, type Pt } from '../../lib/ts';
  import { C, plotStyle, fmt, watchLayout } from '../../lib/viz/theme';

  // Diebold–Mariano in pictures. For every month from Jan 2012 to Dec 2019 we make one-step-ahead forecasts
  // with naive and drift (expanding window), then plot the loss differential
  //   d = |naive error| − |drift error|   (positive = drift missed by less that month).
  // Over a chosen window: average gap ± 2 standard errors, and DM = mean(d) / (sd(d)/√n),
  // which equals R's dm.test(e_naive, e_drift, h = 1, power = 1) for one-step forecasts.
  const PAIRS = {
    PAYEMS: { label: 'Payroll jobs', unit: 'thousand jobs', tag: 'clear winner' },
    MRTSSM4541USS: { label: 'E-commerce sales', unit: '$ millions', tag: 'real but modest' },
    HOUST: { label: 'Housing starts', unit: 'thousand units (annual rate)', tag: 'coin flip' },
  } as const;
  type Sid = keyof typeof PAIRS;
  const FIRST = 24;                           // first origin: two years of training data (2010-2011)

  let sid: Sid = $state('MRTSSM4541USS');
  let rows: { date: Date; d: number; en: number; ed: number }[] = $state([]);
  let len = $state(12);                       // window length, months
  let end = $state(0);                        // index of the last month in the window
  let el: HTMLDivElement;

  async function load() {
    const id = sid;
    const s = await loadSeries(id, { start: '2010-01-01', end: '2019-12-01' });
    if (id !== sid) return;
    const y = s.data.map((p: Pt) => p.value), out: typeof rows = [];
    for (let o = FIRST; o < y.length; o++) {
      const tr = y.slice(0, o), en = y[o] - fcNaive(tr, 1)[0], ed = y[o] - fcDrift(tr, 1)[0];
      out.push({ date: s.data[o].date, d: Math.abs(en) - Math.abs(ed), en, ed });
    }
    rows = out;
    if (end === 0 || end >= out.length) end = out.length - 1;
  }

  const stats = $derived.by(() => {
    if (!rows.length) return null;
    const L = Math.min(len, rows.length), e = Math.max(L - 1, Math.min(end, rows.length - 1));
    const w = rows.slice(e - L + 1, e + 1), d = w.map((r) => r.d), n = d.length, m = mean(d);
    const sd = Math.sqrt(d.reduce((s, x) => s + (x - m) ** 2, 0) / (n - 1)), se = sd / Math.sqrt(n);
    return { w, n, m, se, dm: se > 0 ? m / se : NaN, start: w[0].date, stop: w[n - 1].date };
  });

  function draw() {
    if (!el || !stats) return;
    const { w, m, se } = stats, inW = new Set(w.map((r) => +r.date));
    const W = el.clientWidth;
    const band = [{ a: w[0].date, b: w[w.length - 1].date, lo: m - 2 * se, hi: m + 2 * se }];
    el.replaceChildren(Plot.plot({
      width: W, height: Math.max(260, Math.min(330, W * 0.42)), marginLeft: 60, marginRight: 12, marginTop: 18,
      style: plotStyle(), x: { label: null },
      y: { grid: true, nice: true, tickFormat: fmt, label: `↑ drift better · naive better ↓ (${PAIRS[sid].unit})` },
      ariaLabel: `Monthly accuracy gap between naive and drift for ${PAIRS[sid].label.toLowerCase()}, 2012 to 2019. Window of ${stats.n} months: average gap ${fmt(m)}, DM statistic ${stats.dm.toFixed(2)}.`,
      marks: [
        Plot.ruleY([0], { stroke: C.borderStrong }),
        Plot.rectY(rows.filter((r) => !inW.has(+r.date)), { x: 'date', y: 'd', interval: 'month', fill: C.muted, fillOpacity: 0.18, inset: 0.5 }),
        Plot.rectY(w, { x: 'date', y: 'd', interval: 'month', fill: (r: any) => (r.d >= 0 ? C.s[2] : C.s[1]), fillOpacity: 0.85, inset: 0.5 }),
        Plot.rect(band, { x1: 'a', x2: 'b', y1: 'lo', y2: 'hi', fill: C.forecast, fillOpacity: 0.16, stroke: C.forecast, strokeOpacity: 0.5, strokeDasharray: '3,3' }),
        Plot.ruleY(band, { y: () => m, x1: 'a', x2: 'b', stroke: C.forecast, strokeWidth: 3 }),
        Plot.tip(rows, Plot.pointerX({ x: 'date', y: 'd', title: (r: any) => `${ym(r.date)}\nNaive missed by ${fmt(Math.abs(r.en))}\nDrift missed by ${fmt(Math.abs(r.ed))}\nGap: ${fmt(r.d)} ${PAIRS[sid].unit} (${r.d >= 0 ? 'drift better' : 'naive better'})` })),
      ],
    }));
  }

  $effect(() => { sid; load(); });
  $effect(() => { stats; draw(); });
  onMount(() => watchLayout(el, draw));

  const verdict = $derived(!stats ? '' : Math.abs(stats.dm) >= 2 ? 'Unlikely to be luck' : 'Could easily be luck');
  const winner = $derived(!stats ? '' : stats.m > 0 ? 'Drift' : stats.m < 0 ? 'Naive' : 'Neither');
</script>

<Explorable title="Is the gap real? Watch the band around the average" caption={`Each bar is one month: how much smaller drift's one-month-ahead miss was than naive's (bars above zero: drift did better; below: naive did). The purple line is the average gap over the window you choose, and the band is <b>± 2 standard errors</b>. If the band includes zero, the gap could easily be luck. <b>DM</b> is the average divided by its standard error, the same number R's <code>dm.test(e1, e2, h = 1, power = 1)</code> reports; |DM| above about 2 means p &lt; 0.05. Try a 12-month window and slide it along: the winner can flip. Data: FRED ${sid}, forecasts for Jan 2012–Dec 2019.`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Series">
      {#each Object.entries(PAIRS) as [k, d]}<button class:on={sid === k} aria-pressed={sid === k} onclick={() => (sid = k as Sid)}>{d.label}</button>{/each}
    </div>
    <label class="sl">Window <input type="range" min="6" max={rows.length || 96} step="1" bind:value={len} aria-label="Number of test months in the window" /> <b>{len} mo</b></label>
    {#if stats}
      <label class="sl">Ends <input type="range" min={len - 1} max={rows.length - 1} step="1" bind:value={end} aria-label="Last month of the window" /> <b>{ym(stats.stop)}</b></label>
    {/if}
  {/snippet}
  {#snippet aside()}
    {#if stats}
      <div class="ms" aria-live="polite">
        <div class="stat"><span class="stat-v">{stats.m > 0 ? '+' : ''}{fmt(stats.m)}</span><span class="stat-l"><b>Average gap</b> over {stats.n} months, {PAIRS[sid].unit}. {winner} missed by less.</span></div>
        <div class="stat"><span class="stat-v">± {fmt(2 * stats.se)}</span><span class="stat-l"><b>2 standard errors</b>: how far the average could wander by luck alone</span></div>
        <div class="stat"><span class="stat-v" class:ok={Math.abs(stats.dm) >= 2}>{isFinite(stats.dm) ? stats.dm.toFixed(2) : '—'}</span><span class="stat-l"><b>DM statistic</b> = average ÷ standard error</span></div>
        <p class="verdict" class:ok={Math.abs(stats.dm) >= 2}><b>{verdict}.</b> {Math.abs(stats.dm) >= 2 ? 'The band does not include zero.' : 'The band includes zero.'}</p>
        <p class="hint">Window {ym(stats.start)} – {ym(stats.stop)} · this series: {PAIRS[sid].tag} over the full 8 years</p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart"></div>
  <div class="lg" aria-hidden="true"><span><i class="up"></i>drift missed by less</span><span><i class="dn"></i>naive missed by less</span><span><i class="avg"></i>average gap</span><span><i class="band"></i>± 2 standard errors</span></div>
</Explorable>

<style>
  .chart { min-height: 260px; }
  .ms { display: grid; gap: .8rem; font-size: .82rem; }
  .stat-v.ok, .verdict.ok b { color: var(--good); }
  .verdict { margin: 0; color: var(--text-2); }
  .hint { margin: 0; color: var(--muted); font-size: .75rem; }
  .lg { display: flex; flex-wrap: wrap; gap: .4rem 1rem; font-size: .75rem; color: var(--text-2); margin-top: .4rem; }
  .lg span { display: inline-flex; align-items: center; gap: .35rem; }
  .lg i { display: inline-block; width: 12px; height: 10px; border-radius: 2px; }
  .lg i.up { background: var(--c-s3); } .lg i.dn { background: var(--c-s2); }
  .lg i.avg { height: 3px; background: var(--c-forecast); }
  .lg i.band { background: color-mix(in srgb, var(--c-forecast) 20%, transparent); border: 1px dashed var(--c-forecast); }
</style>
