<script lang="ts">
  // Chapter 11 · Explorable 5: reading variable importance. Permutation importance (out-of-bag) for a
  // random forest on retail sales growth. Drop a feature and watch a correlated one soak up its credit,
  // or regrow with a new seed and watch the bars wobble, while the forecast error barely moves.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { growForest, predictTree, mulberry } from './tree';

  const FEATS = [
    { key: 'g1', label: 'g1 · growth last month' },
    { key: 'g2', label: 'g2 · growth 2 months ago' },
    { key: 'g12', label: 'g12 · growth same month last year' },
    { key: 'month', label: 'month · calendar month' },
  ];
  const NT = 150;
  type Row = { date: Date; x: number[]; y: number };
  let tr: Row[] = [], te: Row[] = [];
  let ready = $state(false);
  let on = $state([true, true, true, true]);
  let seed = $state(1);
  let el: HTMLDivElement;
  type Res = { imp: (number | null)[]; oob: number; mae: number };
  const cache = new Map<string, Res>();
  let cur: Res | null = $state(null);
  let ref: Res | null = $state(null);  // all four features, same seed

  onMount(() => {
    loadSeries('RSXFSN', { start: '2010-01-01' }).then((s) => {
      const d = s.data, g = d.map((p, i) => (i ? 100 * Math.log(p.value / d[i - 1].value) : NaN));
      const R: Row[] = [];
      for (let t = 13; t < d.length; t++) R.push({ date: d[t].date, x: [g[t - 1], g[t - 2], g[t - 12], d[t].date.getMonth() + 1], y: g[t] });
      tr = R.filter((r) => r.date.getFullYear() < 2023);
      te = R.filter((r) => r.date.getFullYear() >= 2023);
      ready = true;
    });
    return watchLayout(el, draw);
  });

  /** Fit a forest on the chosen features; permutation importance = rise in each tree's OOB MSE when one
   *  feature is shuffled among that tree's OOB rows (randomForest's recipe), as a % of the forest's OOB MSE. */
  function fit(mask: boolean[], sd: number): Res {
    const key = mask.map(Number).join('') + '-' + sd;
    if (cache.has(key)) return cache.get(key)!;
    const use = mask.map((b, j) => (b ? j : -1)).filter((j) => j >= 0);
    const X = tr.map((r) => use.map((j) => r.x[j])), y = tr.map((r) => r.y), n = y.length;
    const F = growForest(X, y, { nTrees: NT, mtry: Math.min(2, use.length), minSplit: 5, seed: sd });
    const s = new Array(n).fill(0), c = new Array(n).fill(0), inc = use.map(() => 0);
    const rng = mulberry(sd + 99);
    F.trees.forEach((T, b) => {
      const oob: number[] = [];
      for (let i = 0; i < n; i++) if (!F.inbag[b][i]) oob.push(i);
      if (!oob.length) return;
      let e0 = 0;
      for (const i of oob) { const p = predictTree(T, X[i]); s[i] += p; c[i]++; e0 += (y[i] - p) ** 2; }
      use.forEach((_, j) => {
        const perm = oob.slice();
        for (let k = perm.length - 1; k > 0; k--) { const m = Math.floor(rng() * (k + 1)); [perm[k], perm[m]] = [perm[m], perm[k]]; }
        let e1 = 0;
        oob.forEach((i, k) => { const xx = X[i].slice(); xx[j] = X[perm[k]][j]; e1 += (y[i] - predictTree(T, xx)) ** 2; });
        inc[j] += (e1 - e0) / oob.length / NT;
      });
    });
    let mse = 0, m = 0;
    for (let i = 0; i < n; i++) if (c[i]) { mse += (y[i] - s[i] / c[i]) ** 2; m++; }
    mse /= m;
    const mae = te.reduce((a, r) => a + Math.abs(r.y - F.trees.reduce((q, T) => q + predictTree(T, use.map((j) => r.x[j])), 0) / NT), 0) / te.length;
    const imp: (number | null)[] = mask.map(() => null);
    use.forEach((j, k) => (imp[j] = (100 * inc[k]) / mse));
    const res = { imp, oob: Math.sqrt(mse), mae };
    cache.set(key, res);
    return res;
  }
  $effect(() => {
    if (!ready) return;
    cur = fit(on, seed);
    ref = fit([true, true, true, true], seed);
  });

  function toggle(j: number) {
    if (on[j] && on.filter(Boolean).length === 1) return; // keep at least one feature
    on = on.map((b, k) => (k === j ? !b : b));
  }

  function draw() {
    if (!el || !cur || !ref) return;
    const W = el.clientWidth, narrow = W < 520;
    if (W < 280) return;   // not laid out yet: watchLayout redraws once it has a real width
    const rows = FEATS.map((f, j) => ({ lab: narrow ? f.key : f.label, v: cur!.imp[j], r: ref!.imp[j] }));
    const max = Math.max(1600, ...rows.map((d) => d.v ?? 0)) * 1.08;
    el.replaceChildren(Plot.plot({
      width: W, height: 230, marginLeft: narrow ? 56 : 210, marginRight: 64, marginTop: 8, marginBottom: 38,
      style: plotStyle(),
      x: { domain: [0, max], grid: true, label: '% increase in out-of-bag error when shuffled →', tickFormat: (d: number) => d.toLocaleString() },
      y: { domain: rows.map((d) => d.lab), label: null, tickSize: 0 },
      marks: [
        Plot.barX(rows.filter((d) => d.v !== null), { x: 'v', y: 'lab', fill: C.forecast, rx: 3, insetTop: 6, insetBottom: 6 }),
        Plot.tickX(rows.filter((d) => d.r !== null && d.v !== null), { x: 'r', y: 'lab', stroke: C.text, strokeWidth: 2, strokeDasharray: '3,2', insetTop: 2, insetBottom: 2 }),
        Plot.text(rows.filter((d) => d.v !== null), { x: 'v', y: 'lab', dx: 6, textAnchor: 'start', text: (d: any) => `${Math.round(d.v)}%`, fill: C.text, fontSize: 12, fontWeight: 650 }),
        Plot.text(rows.filter((d) => d.v === null), { x: 0, y: 'lab', dx: 6, textAnchor: 'start', text: () => 'dropped from the model', fill: C.muted, fontSize: 12, fontStyle: 'italic' }),
        Plot.ruleX([0], { stroke: C.borderStrong }),
      ],
      ariaLabel: `Permutation importance of each feature: ${rows.map((d) => `${d.lab.split(' ')[0]} ${d.v === null ? 'dropped' : Math.round(d.v) + ' percent'}`).join(', ')}`,
    } as any));
  }
  $effect(() => { cur; ref; draw(); });

  const fmt2 = (v: number) => v.toFixed(2);
  const story = $derived.by(() => {
    if (!cur || !ref) return '';
    const [g1, g2, g12, mo] = on;
    const pct = (v: number | null) => `${Math.round(v ?? 0)}%`;
    if (g12 && mo) return 'Both seasonal features are in the model, so they share the credit for seasonality. Neither bar shows how much seasonality matters on its own.';
    if (g12 && !mo) return `Without month, g12 alone carries the seasonal pattern: its bar grows from ${pct(ref.imp[2])} to ${pct(cur.imp[2])}, yet the test error rises only from ${fmt2(ref.mae)} to ${fmt2(cur.mae)} points.`;
    if (!g12 && mo) return `Without g12, month takes over: its bar grows from ${pct(ref.imp[3])} to ${pct(cur.imp[3])}, and the test error barely changes (${fmt2(ref.mae)} → ${fmt2(cur.mae)} points).`;
    return `With no seasonal feature left, the test error jumps from ${fmt2(ref.mae)} to ${fmt2(cur.mae)} points. That is the real cost of losing seasonality, a number no single bar told you.`;
  });
</script>

<Explorable title="Importance is shared, not owned: drop a feature and its twin takes the credit" caption="A random forest ({NT} trees) forecasts next month's retail sales growth from four features. Each bar is <b>permutation importance</b>: how much the forest's out-of-bag error grows when that one feature is shuffled. The dashed tick marks each feature's bar in the full four-feature model. <b>Drop month</b> or <b>drop g12</b>: the other seasonal feature's bar shoots up, while the test error (2023 onward) barely moves. Drop both and the error jumps. Then press <b>Regrow</b> to see how much the bars wobble from one random seed to the next. Here month enters as a number 1–12 (as in the Python lab), so the ranking differs from the R lab, which treats month as a category. Data: FRED RSXFSN, not seasonally adjusted, trained 2011–2022.">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Features in the model">
      {#each FEATS as f, j}
        <button class:on={on[j]} aria-pressed={on[j]} onclick={() => toggle(j)} title={on[j] ? `Drop ${f.key}` : `Add ${f.key} back`}>{on[j] ? '✓ ' : '+ '}{f.key}</button>
      {/each}
    </div>
    <button class="btn" onclick={() => (seed = (seed % 6) + 1)}>Regrow with a new seed</button>
    <span class="seedv">seed {seed}</span>
  {/snippet}
  {#snippet aside()}
    {#if cur && ref}
      <div class="st"><span class="stat-l">Test error, 2023 onward (MAE)</span><span class="stat-v">{fmt2(cur.mae)} <small>pp</small></span><span class="stat-s">all four features: {fmt2(ref.mae)} pp</span></div>
      <div class="st"><span class="stat-l">Out-of-bag error (RMSE)</span><span class="stat-v">{fmt2(cur.oob)} <small>pp</small></span><span class="stat-s">all four features: {fmt2(ref.oob)} pp</span></div>
      <p class="story" aria-live="polite">{story}</p>
      <p class="hint">pp = percentage points of monthly growth. Importance has no sign and no units of the target: it says how much the model leans on a feature, not which way or why.</p>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 230px; }
  .btn { all: unset; cursor: pointer; font: 600 .78rem var(--font-ui); padding: .38rem .8rem; border-radius: 8px; border: 1px solid var(--border-strong); color: var(--text); background: var(--bg); }
  .btn:hover { background: var(--surface-2); }
  .btn:focus-visible { outline: 2px solid var(--accent-2); }
  .seedv { font: 600 .78rem var(--font-mono); color: var(--muted); }
  .st { display: flex; flex-direction: column; gap: .1rem; margin-bottom: .7rem; }
  .stat-l { font-size: .76rem; color: var(--muted); }
  .stat-v { font: 650 1.35rem/1.1 var(--font-ui); font-variant-numeric: tabular-nums; color: var(--text); }
  .stat-v small { font-size: .75rem; color: var(--muted); font-weight: 500; }
  .stat-s { font-size: .74rem; color: var(--muted); }
  .story { font-size: .86rem; color: var(--text-2); margin: .4rem 0 .6rem; line-height: 1.45; }
  .hint { font-size: .74rem; color: var(--muted); margin: 0; }
</style>
