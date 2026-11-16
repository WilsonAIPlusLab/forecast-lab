<script lang="ts">
  // Why a straight line breaks: the linear probability model (LPM) vs the logit on real bank-marketing clients.
  // Top: one predictor up close (Euribor), binned subscription rates, LPM line vs logistic S-curve.
  // Bottom: every client's predicted probability under both models, for a growing set of predictors (fitted live, IRLS).
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { BASE } from '../../lib/runtime/status';
  import { loadCSV, design, logit, ols, plogis, dot, type Row, type Term } from './nlmath';

  const P: Term = { name: 'poutcome', cat: true, ref: 'nonexistent' };
  const N = (name: string): Term => ({ name });
  const K = (name: string): Term => ({ name, cat: true });
  const five = [N('age'), K('contact'), N('campaign'), P, N('euribor3m')];
  const STEPS = [
    { label: 'Euribor only', terms: [N('euribor3m')] },
    { label: '+ past outcome', terms: [N('euribor3m'), P] },
    { label: '5 pre-call facts', terms: five },
    { label: '+ month & weekday', terms: [...five, K('month'), K('day_of_week')] },
    { label: 'All 19 columns', terms: [N('age'), K('job'), K('marital'), K('education'), K('default'), K('housing'), K('loan'), K('contact'), K('month'), K('day_of_week'), N('campaign'), N('pdays'), N('previous'), P, N('emp_var_rate'), N('cons_price_idx'), N('cons_conf_idx'), N('euribor3m'), N('nr_employed')] },
  ];

  let rows: Row[] = [];
  let y: number[] = [];
  let step = $state(2);
  let busy = $state(false);
  type Fit = { lpm: number[]; lg: number[]; eta: number[]; k: number };
  let fits: Record<number, Fit> = {};
  let cur = $state<Fit | null>(null);
  let elTop: HTMLDivElement, elBot: HTMLDivElement;
  const jitter: number[] = [];

  async function load() {
    rows = await loadCSV(BASE, 'bank_marketing.csv');
    y = rows.map((r) => (r.y === 'yes' ? 1 : 0));
    for (let i = 0; i < rows.length; i++) jitter.push(((i * 7919) % 1000) / 1000);
    fitStep();
  }

  function fitStep() {
    if (!rows.length) return;
    if (fits[step]) { cur = fits[step]; return; }
    busy = true;
    const s = step;
    setTimeout(() => {
      const { X, cols } = design(rows, STEPS[s].terms);
      const g = logit(X, y);
      const f = { lpm: ols(X, y).fitted, lg: g.p, eta: X.map((r) => dot(r, g.beta)), k: cols.length };
      fits[s] = f;
      if (s === step) { cur = f; busy = false; }
    }, 30);
  }

  const counts = $derived.by(() => { const c = cur; return c ? { neg: c.lpm.filter((v: number) => v < -1e-9).length, over: c.lpm.filter((v: number) => v > 1).length, min: Math.min(...c.lpm), max: Math.max(...c.lpm) } : null; });

  // Top panel: clients placed by their logit score; binned share of yeses; S-curve vs a least-squares line on the score.
  const top = $derived.by(() => {
    const c = cur; if (!c) return null;
    const n = c.eta.length, idx = c.eta.map((_, i) => i).sort((a, b) => c.eta[a] - c.eta[b]);
    const nb = 14, bins = Array.from({ length: nb }, (_, k) => {
      const part = idx.slice(Math.floor((k * n) / nb), Math.floor(((k + 1) * n) / nb));
      return { x: part.reduce((s, i) => s + c.eta[i], 0) / part.length, rate: part.reduce((s, i) => s + y[i], 0) / part.length, n: part.length };
    });
    const mx = c.eta.reduce((s, v) => s + v, 0) / n, my = y.reduce((s, v) => s + v, 0) / n;
    let sxy = 0, sxx = 0; c.eta.forEach((v, i) => { sxy += (v - mx) * (y[i] - my); sxx += (v - mx) ** 2; });
    const lb = sxy / sxx, la = my - lb * mx;
    const lo = Math.min(...c.eta) - 0.3, hi = Math.max(...c.eta) + 0.6;
    return { bins, la, lb, lo, hi, z0: -la / lb };
  });

  function drawTop() {
    const t = top;
    if (!elTop || !t || !cur) return;
    const W = elTop.clientWidth, H = Math.max(250, Math.min(320, W * 0.42));
    if (W < 200) return; // skip transient zero-width layouts (no negative-size marks)
    const xs = Array.from({ length: 161 }, (_, i) => t.lo + (i * (t.hi - t.lo)) / 160);
    const curve = xs.map((x) => ({ x, p: plogis(x) }));
    const line = xs.map((x) => ({ x, p: t.la + t.lb * x }));
    const rug = cur.eta.map((e, i) => ({ x: e, y: y[i] ? 1.03 + jitter[(i * 13) % rows.length] * 0.05 : -0.03 - jitter[(i * 13) % rows.length] * 0.05 }));
    const pmin = Math.min(-0.12, t.la + t.lb * t.lo - 0.02), pmax = Math.max(1.1, t.la + t.lb * t.hi + 0.02);
    const marks: any[] = [
      Plot.rectY([0], { x1: t.lo, x2: t.hi, y1: pmin, y2: 0, fill: C.danger, fillOpacity: 0.1 }),
      Plot.rectY([0], { x1: t.lo, x2: t.hi, y1: 1, y2: pmax, fill: C.danger, fillOpacity: 0.1 }),
      Plot.text(['Impossible: below 0%'], { x: t.hi, y: pmin, dy: -6, textAnchor: 'end', fill: C.danger, fontSize: 12, fontWeight: 650 }),
      Plot.ruleY([0, 1], { stroke: C.borderStrong, strokeWidth: 1.5 }),
      Plot.dot(rug, { x: 'x', y: 'y', r: 1.1, fill: C.muted, fillOpacity: 0.3 }),
      Plot.lineY(line, { x: 'x', y: 'p', stroke: C.s[5], strokeWidth: 2.4, strokeDasharray: '6,4' }),
      Plot.lineY(curve, { x: 'x', y: 'p', stroke: C.fitted, strokeWidth: 3 }),
      Plot.dot(t.bins, { x: 'x', y: 'rate', r: 5, fill: C.actual, stroke: 'var(--surface)', strokeWidth: 1.2, tip: true, title: (d: any) => `${d.n} clients with scores near ${d.x.toFixed(2)}\n${(100 * d.rate).toFixed(1)}% subscribed\nS-curve: ${(100 * plogis(d.x)).toFixed(1)}%` }),
      Plot.text([{ x: t.lo, p: t.la + t.lb * t.lo }], { x: 'x', y: 'p', text: () => 'Straight line', textAnchor: 'start', dx: 4, dy: -12, fill: C.s[5], fontSize: 12, fontWeight: 700, stroke: 'var(--surface)', strokeWidth: 3, paintOrder: 'stroke' }),
      Plot.text([{ x: t.hi, p: plogis(t.hi) }], { x: 'x', y: 'p', text: () => 'S-curve (logit)', textAnchor: 'end', dy: -12, fill: C.fitted, fontSize: 12, fontWeight: 700, stroke: 'var(--surface)', strokeWidth: 3, paintOrder: 'stroke' }),
      Plot.text([{ x: t.lo, p: 0.8 }], { x: 'x', y: 'p', text: () => 'Gold dots: share who said yes,\nin 14 equal-size groups of clients', textAnchor: 'start', dx: 4, fill: C.actual, fontSize: 12, lineHeight: 1.2 }),
    ];
    if (t.z0 > t.lo) marks.push(Plot.ruleX([t.z0], { y1: pmin, y2: 0.15, stroke: C.danger, strokeDasharray: '3,3' }));
    const chart = Plot.plot({
      width: W, height: H, marginLeft: 48, marginRight: 16, marginTop: 18, marginBottom: 36, style: plotStyle(),
      x: { domain: [t.lo, t.hi], label: "Client score: the logit's log-odds of a yes", labelAnchor: 'center', labelArrow: 'none' },
      y: { domain: [pmin, pmax], grid: true, label: null, tickFormat: (d: number) => `${Math.round(d * 100)}%`, ticks: [0, 0.25, 0.5, 0.75, 1] },
      marks,
    });
    chart.setAttribute('aria-label', 'Clients ordered by model score. The share who subscribed (gold) follows the S-curve; a straight line through the same 0/1 data drops below zero for low scores.');
    elTop.replaceChildren(chart);
  }

  function drawBot() {
    if (!elBot || !cur) return;
    const W = elBot.clientWidth, H = 190;
    if (W < 200) return; // skip transient zero-width layouts
    const d = cur.lpm.flatMap((v, i) => [
      { m: 1, p: v, y: 1 + (jitter[i] - 0.5) * 0.62, neg: v < -1e-9 || v > 1 },
      { m: 0, p: cur!.lg[i], y: (jitter[i] - 0.5) * 0.62, neg: false },
    ]);
    const chart = Plot.plot({
      width: W, height: H, marginLeft: 130, marginRight: 16, marginTop: 8, marginBottom: 34, style: plotStyle(),
      x: { domain: [-0.15, 1.05], label: "Each client's predicted probability of saying yes", labelAnchor: 'center', labelArrow: 'none', tickFormat: (d: number) => `${Math.round(d * 100)}%` },
      y: { domain: [-0.45, 1.45], ticks: [0, 1], tickFormat: (t: number) => (t ? 'Straight line (LPM)' : 'S-curve (logit)'), tickSize: 0, label: null },
      marks: [
        Plot.rectX([0], { x1: -0.15, x2: 0, y1: -0.45, y2: 1.45, fill: C.danger, fillOpacity: 0.1 }),
        Plot.ruleX([0, 1], { stroke: C.borderStrong, strokeWidth: 1.5 }),
        Plot.dot(d.filter((r) => !r.neg), { x: 'p', y: 'y', r: 1.4, fill: (r: any) => (r.m ? C.s[5] : C.fitted), fillOpacity: 0.35 }),
        Plot.dot(d.filter((r) => r.neg), { x: 'p', y: 'y', r: 3, symbol: 'times', stroke: C.danger, strokeWidth: 1.6 }),
      ],
    });
    chart.setAttribute('aria-label', `Predicted probabilities for 4,119 clients. The straight-line model puts ${counts?.neg ?? 0} clients below zero; the logit puts none.`);
    elBot.replaceChildren(chart);
  }

  $effect(() => { top; drawTop(); });
  $effect(() => { cur; drawBot(); });
  $effect(() => { step; fitStep(); });
  onMount(() => {
    load();
    const a = watchLayout(elTop, drawTop), b = watchLayout(elBot, drawBot);
    return () => { a(); b(); };
  });
</script>

<Explorable title="A straight line through 0/1 data predicts the impossible" caption="4,119 clients of a Portuguese bank. Pick which pre-call facts the models may use; both are refitted in your browser (least squares for the straight line, IRLS for the logit, the same algorithm R's <code>glm()</code> uses). <b>Top:</b> clients placed by their logit score; grey ticks at 0% and 100% are individual clients (no / yes), gold dots the share who subscribed in each group. The gold dots follow the S-curve; a straight line through the same 0/1 data runs below 0%. <b>Bottom:</b> every client's fitted probability from the actual linear probability model and from the logit. Red crosses are impossible forecasts. Data: UCI Bank Marketing (Moro et al. 2014), CC BY 4.0.">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Predictors in the model">
      {#each STEPS as s, i}<button class:on={step === i} aria-pressed={step === i} onclick={() => (step = i)}>{s.label}</button>{/each}
    </div>
  {/snippet}
  {#snippet aside()}
    <div class="side" aria-live="polite">
      {#if counts && cur}
        <div class="stat"><span class="stat-v neg">{counts.neg.toLocaleString()}</span><span class="stat-l">clients get a <b>negative</b> probability from the straight line{counts.over ? `, and ${counts.over} ${counts.over === 1 ? 'gets' : 'get'} more than 100%` : ''}</span></div>
        <div class="stat"><span class="stat-v">0</span><span class="stat-l">impossible values from the logit, whatever you add</span></div>
        <p class="rng">LPM range: <b>{(100 * counts.min).toFixed(1)}%</b> to <b>{(100 * counts.max).toFixed(1)}%</b> · {cur.k} coefficients{busy ? ' · fitting…' : ''}</p>
      {:else}
        <p class="rng">Loading 4,119 clients…</p>
      {/if}
      <div class="three">
        <div class="eyebrow">The LPM's three problems</div>
        <ol>
          <li><b>Out-of-range forecasts</b> below 0 or above 1.</li>
          <li><b>Heteroskedastic by construction</b>: a 0/1 outcome has variance p(1 − p), which changes with p.</li>
          <li><b>Constant marginal effects</b>: a straight line rises by the same amount everywhere; the gold dots rise slowly at low scores and fast at high ones, like the S-curve.</li>
        </ol>
      </div>
    </div>
  {/snippet}
  <div bind:this={elTop} class="chart-top"></div>
  <div bind:this={elBot} class="chart-bot"></div>
</Explorable>

<style>
  .chart-top { min-height: 250px; }
  .chart-bot { min-height: 190px; margin-top: .6rem; border-top: 1px dashed var(--border); padding-top: .6rem; }
  .side { display: grid; gap: .9rem; font-size: .84rem; }
  .neg { color: var(--danger) !important; }
  .rng { color: var(--muted); font-size: .78rem; margin: 0; font-variant-numeric: tabular-nums; }
  .three { border-top: 1px dashed var(--border); padding-top: .7rem; color: var(--text-2); }
  .three ol { padding-left: 1.1rem; margin: .4rem 0 0; display: grid; gap: .35rem; font-size: .8rem; }
</style>
