<script lang="ts">
  // Signature explorable 3: SHAP summary (beeswarm) for every month since 2005, plus a dependence view.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import data from './shap_data.json';

  const F: string[] = data.features;
  const NAMES: Record<string, string> = {
    month: 'Calendar month', growth_ly: 'Same month last year’s growth', growth_lm: 'Last month’s growth',
    yoy_lm: 'Last month’s 12-month growth', weekend: 'Weekend days', sent_lm: 'Consumer sentiment', unrate_lm: 'Unemployment rate',
  };
  const UNITS: Record<string, string> = { month: '(1 = Jan … 12 = Dec)', growth_ly: '(%)', growth_lm: '(%)', yoy_lm: '(%)', weekend: '(days)', sent_lm: '(index)', unrate_lm: '(%)' };
  const B = data.bees as { date: string[]; test: boolean[]; shap: number[][]; x: (number | null)[][] };
  const n = B.date.length;
  const meanAbs = F.map((_, j) => B.shap[j].reduce((s, v) => s + Math.abs(v), 0) / n);
  const order = F.map((f, j) => ({ f, j, m: meanAbs[j] })).sort((a, b) => b.m - a.m);

  let mode: 'summary' | 'dependence' = $state('summary');
  let dep = $state('growth_ly');
  let el: HTMLDivElement;

  // beeswarm layout: bin x, stack points symmetrically within each bin
  function swarm() {
    const pts: any[] = [];
    order.forEach(({ f, j }, row) => {
      const xs = B.x[j].filter((v) => v !== null) as number[];
      const sorted = [...xs].sort((a, b) => a - b);
      const rank = (v: number) => (sorted.length > 1 ? sorted.findIndex((s) => s >= v) / (sorted.length - 1) : 0.5);
      const vals = B.shap[j];
      const lo = Math.min(...vals), hi = Math.max(...vals), bw = Math.max((hi - lo) / 90, 0.02);
      const bins = new Map<number, number[]>();
      vals.forEach((v, i) => { const b = Math.round(v / bw); (bins.get(b) || bins.set(b, []).get(b)!).push(i); });
      const maxCount = Math.max(...[...bins.values()].map((a) => a.length));
      const step = Math.min(0.03, 0.42 / Math.max(1, maxCount / 2));
      for (const idx of bins.values()) idx.forEach((i, k) => {
        const off = (k % 2 ? 1 : -1) * Math.ceil(k / 2) * step;
        const x = B.x[j][i];
        pts.push({ f, row, y: row + off, shap: vals[i], date: B.date[i], val: x, c: x === null ? null : rank(x), test: B.test[i] });
      });
    });
    return pts;
  }
  const PTS = swarm();
  const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const fmtVal = (f: string, v: number | null) => (v === null ? 'not published' : f === 'month' ? MON[v - 1] : f === 'weekend' ? String(v) : (+v).toFixed(1));
  const fmtD = (s: string) => { const [y, m] = s.split('-'); return `${MON[+m - 1]} ${y}`; };

  function draw() {
    if (!el) return;
    const W = el.clientWidth;
    const lo = C.s[0], hi = C.s[1];
    if (mode === 'summary') {
      el.replaceChildren(Plot.plot({
        width: W, height: 60 + order.length * 58, marginLeft: Math.min(210, W * 0.32), marginRight: 16, marginBottom: 40,
        style: plotStyle(),
        ariaLabel: 'Beeswarm of SHAP values per feature, every month 2005 to 2026. Same month last year\'s growth and calendar month spread widest.',
        x: { label: 'SHAP value: push on predicted monthly growth (percentage points)', grid: true, tickFormat: (v: number) => (v > 0 ? `+${v}` : `${v}`) },
        y: { domain: [order.length - 0.5, -0.5], ticks: order.map((_, i) => i), tickFormat: (i: number) => NAMES[order[i]?.f] ?? '', label: null, tickSize: 0 },
        color: { type: 'linear', domain: [0, 1], range: [lo, hi] },
        marks: [
          Plot.ruleX([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
          Plot.dot(PTS.filter((p) => p.c === null), { x: 'shap', y: 'y', r: 3, stroke: C.muted, fill: 'none' }),
          Plot.dot(PTS.filter((p) => p.c !== null), { x: 'shap', y: 'y', r: 2.6, fill: 'c', fillOpacity: 0.85 }),
          Plot.tip(PTS, Plot.pointer({ x: 'shap', y: 'y', title: (p: any) => `${fmtD(p.date)}\n${NAMES[p.f]}: ${fmtVal(p.f, p.val)}\nSHAP: ${p.shap >= 0 ? '+' : '−'}${Math.abs(p.shap).toFixed(2)} pts of growth` })),
        ],
      }));
    } else {
      const j = F.indexOf(dep);
      const rows = B.date.map((d, i) => ({ date: d, x: B.x[j][i], shap: B.shap[j][i], test: B.test[i], dec: d.slice(5, 7) === '12' })).filter((r) => r.x !== null);
      el.replaceChildren(Plot.plot({
        width: W, height: Math.max(300, Math.min(420, W * 0.5)), marginLeft: 56, marginRight: 16, marginBottom: 42,
        style: plotStyle(),
        ariaLabel: `Dependence plot: ${NAMES[dep]} against its SHAP value`,
        x: { label: `${NAMES[dep]} ${UNITS[dep]}`, grid: true, tickFormat: dep === 'month' ? (v: number) => MON[v - 1] ?? '' : undefined, ticks: dep === 'month' ? 12 : dep === 'weekend' ? [8, 9, 10] : undefined },
        y: { label: 'SHAP value (pts of monthly growth)', grid: true, tickFormat: (v: number) => (v > 0 ? `+${v}` : `${v}`) },
        marks: [
          Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
          Plot.dot(rows.filter((r) => !r.test), { x: 'x', y: 'shap', r: 3, fill: C.history, fillOpacity: 0.45 }),
          Plot.dot(rows.filter((r) => r.test), { x: 'x', y: 'shap', r: 3.6, fill: C.actual, stroke: C.surface, strokeWidth: 0.6 }),
          Plot.tip(rows, Plot.pointer({ x: 'x', y: 'shap', title: (r: any) => `${fmtD(r.date)}${r.test ? ' (test period)' : ''}\n${NAMES[dep]}: ${fmtVal(dep, r.x)}\nSHAP: ${r.shap >= 0 ? '+' : '−'}${Math.abs(r.shap).toFixed(2)} pts` })),
        ],
      }));
    }
  }
  onMount(() => watchLayout(el, draw));
  $effect(() => { mode; dep; draw(); });
  const total = meanAbs.reduce((a, b) => a + b, 0);
</script>

<Explorable title="Seasonal features move every forecast; consumer sentiment never does" caption={`Each dot is one month (January 2005 to September 2026), explained by the model trained through 2022. <b>Summary</b>: position = how far that feature pushed predicted growth that month; color = the feature's value that month, from <span style="color:var(--c-s1);font-weight:650">low</span> to <span style="color:var(--c-s2);font-weight:650">high</span> (hollow = missing). <b>Dependence</b>: one feature's value against its push; gold dots are the 2023–2026 test months. Units: percentage points of month-over-month growth. Data: FRED RSXFSN (NSA), UMCSENT, UNRATE.`}>
  {#snippet controls()}
    <span class="seg" role="group" aria-label="View">
      <button class:on={mode === 'summary'} aria-pressed={mode === 'summary'} onclick={() => (mode = 'summary')}>Summary (beeswarm)</button>
      <button class:on={mode === 'dependence'} aria-pressed={mode === 'dependence'} onclick={() => (mode = 'dependence')}>Dependence</button>
    </span>
    {#if mode === 'dependence'}
      <label class="sl">Feature
        <select bind:value={dep} aria-label="Feature for the dependence plot">{#each order as o}<option value={o.f}>{NAMES[o.f]}</option>{/each}</select>
      </label>
    {/if}
  {/snippet}
  {#snippet aside()}
    <div class="side">
      <div class="eyebrow">Mean |SHAP|, share of total</div>
      <ul class="imp">
        {#each order as o}
          <li><button class:on={mode === 'dependence' && dep === o.f} onclick={() => { dep = o.f; mode = 'dependence'; }} aria-label={`Show dependence plot for ${NAMES[o.f]}`}>
            <span class="nm">{NAMES[o.f]}</span><span class="track"><span class="fill" style={`width:${(100 * o.m) / order[0].m}%`}></span></span><span class="pc">{((100 * o.m) / total).toFixed(0)}%</span>
          </button></li>
        {/each}
      </ul>
      <p class="hint">Click a feature to see its dependence plot. Notice how <i>calendar month</i> and <i>same month last year's growth</i> share the credit for seasonality: they carry the same information.</p>
    </div>
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 360px; }
  select { font: inherit; font-size: .8rem; background: var(--bg); color: var(--text); border: 1px solid var(--border); border-radius: 7px; padding: .25rem .4rem; }
  .side { font-size: .82rem; color: var(--text-2); }
  .eyebrow { font-size: .8rem; font-weight: 650; color: var(--muted); margin-bottom: .4rem; }
  .imp { list-style: none; padding: 0; margin: 0 0 .7rem; }
  .imp button { all: unset; cursor: pointer; display: grid; grid-template-columns: 1fr 60px 34px; gap: .4rem; align-items: center; width: 100%; padding: .22rem .3rem; border-radius: 6px; box-sizing: border-box; }
  .imp button:hover, .imp button.on { background: var(--surface-2); }
  .imp button:focus-visible { outline: 2px solid var(--accent-2); }
  .nm { line-height: 1.25; }
  .track { height: 8px; background: var(--surface-3); border-radius: 4px; overflow: hidden; }
  .fill { display: block; height: 100%; background: var(--c-s3); }
  .pc { text-align: right; font-variant-numeric: tabular-nums; color: var(--text); }
  .hint { color: var(--muted); font-size: .78rem; margin: 0; line-height: 1.45; }
</style>
