<script lang="ts">
  // Marginal effects aren't constant: a tangent slides along the fitted S-curve of P(yes) against Euribor for a chosen
  // client profile (the chapter's five-fact logit, refitted here on the same 2,882 training clients as the labs),
  // compared with the average marginal effect (AME) and the marginal effect at the mean (MEM).
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { BASE } from '../../lib/runtime/status';
  import { loadCSV, design, logit, plogis, dot } from './nlmath';

  const PROFILES = [
    { k: 'none', label: 'Never contacted before', vals: { poutcomefailure: 0, poutcomesuccess: 0 } },
    { k: 'success', label: 'Past campaign: success', vals: { poutcomefailure: 0, poutcomesuccess: 1 } },
  ];
  let ready = $state(false);
  let beta: number[] = [], cols: string[] = [], xbar: number[] = [];
  let xs: number[] = [];
  let x0 = $state(1.3);
  let prof = $state('none');
  let compare = $state(false);
  let el: HTMLDivElement;
  let ame = $state(0), mem = $state(0), meanEur = $state(0), gap = $state(0), n = $state(0), meMin = $state(0), meMax = $state(0);

  async function load() {
    const rows = await loadCSV(BASE, 'bank_marketing.csv');
    // same stratified split as the labs: position within outcome class, positions 0-2 of every 10 = test
    const seen: Record<string, number> = {};
    const train = rows.filter((r) => { const k = String(r.y); const pos = (seen[k] = (seen[k] ?? -1) + 1); return pos % 10 >= 3; });
    const y = train.map((r) => (r.y === 'yes' ? 1 : 0));
    const d = design(train, [{ name: 'age' }, { name: 'contact', cat: true }, { name: 'campaign' }, { name: 'poutcome', cat: true, ref: 'nonexistent' }, { name: 'euribor3m' }]);
    const g = logit(d.X, y);
    beta = g.beta; cols = d.cols; n = rows.length;
    const j = cols.indexOf('euribor3m'), b = beta[j];
    const me = g.p.map((p) => b * p * (1 - p));
    ame = me.reduce((s, v) => s + v, 0) / me.length;
    meMin = Math.min(...me); meMax = Math.max(...me);
    xbar = cols.map((_, c) => d.X.reduce((s, r) => s + r[c], 0) / d.X.length);
    const pm = plogis(dot(xbar, beta)); mem = b * pm * (1 - pm);
    meanEur = xbar[j];
    xs = rows.map((r) => Number(r.euribor3m));
    gap = xs.filter((x) => x >= 2 && x <= 4).length;
    ready = true;
  }

  // log-odds for a client profile at Euribor x (age 40, mobile phone, first call of the campaign), or for the "average client"
  function eta(x: number, avg = false) {
    if (avg) return beta.reduce((s, b, c) => s + b * (cols[c] === 'euribor3m' ? x : xbar[c]), 0);
    const v: Record<string, number> = { '(Intercept)': 1, age: 40, contacttelephone: 0, campaign: 1, euribor3m: x, ...PROFILES.find((p) => p.k === prof)!.vals };
    return beta.reduce((s, b, c) => s + b * (v[cols[c]] ?? 0), 0);
  }
  const bEur = $derived(ready ? beta[cols.indexOf('euribor3m')] : 0);
  const at = $derived.by(() => {
    if (!ready) return { p: 0, slope: 0, exact: 0 };
    prof;
    const p = plogis(eta(x0)), slope = bEur * p * (1 - p);
    return { p, slope, exact: plogis(eta(x0 + 1)) - p };
  });

  function draw() {
    if (!el || !ready) return;
    const W = el.clientWidth, H = Math.max(280, Math.min(360, W * 0.48));
    const grid = Array.from({ length: 121 }, (_, i) => 0.4 + (i * 5) / 120);
    const curve = grid.map((x) => ({ x, p: plogis(eta(x)) }));
    const tan = (xc: number, avg = false) => { const p = plogis(eta(xc, avg)), s = bEur * p * (1 - p); return [xc - 0.9, xc + 0.9].map((x) => ({ x, p: p + s * (x - xc) })); };
    const bins = new Map<number, number>();
    xs.forEach((x) => { const k = Math.floor(x * 5) / 5; bins.set(k, (bins.get(k) ?? 0) + 1); });
    const maxB = Math.max(...bins.values());
    const top = prof === 'success' ? 0.8 : 0.4;
    const hist = [...bins.entries()].map(([k, c]) => ({ x1: k, x2: k + 0.2, h: (0.18 * top * c) / maxB, c }));
    const marks: any[] = [
      Plot.rectY(hist, { x1: 'x1', x2: 'x2', y1: 0, y2: 'h', fill: C.muted, fillOpacity: 0.28, insetLeft: 0.5, insetRight: 0.5, tip: true, title: (d: any) => `Euribor ${d.x1.toFixed(1)}–${d.x2.toFixed(1)}%: ${d.c} calls` }),
      Plot.text([{ x: 3.0, p: 0.035 * top }], { x: 'x', y: 'p', text: () => '← grey bars: where the calls happened →', textAnchor: 'middle', fill: C.muted, fontSize: 12 }),
      Plot.lineY(curve, { x: 'x', y: 'p', stroke: C.fitted, strokeWidth: 3 }),
      Plot.text([curve[0]], { x: 'x', y: 'p', text: () => PROFILES.find((p) => p.k === prof)!.label, dx: 6, dy: -14, textAnchor: 'start', fill: C.fitted, fontSize: 12, fontWeight: 700, stroke: 'var(--surface)', strokeWidth: 3, paintOrder: 'stroke' }),
    ];
    if (compare) {
      const avgCurve = grid.map((x) => ({ x, p: plogis(eta(x, true)) }));
      const pm = plogis(eta(meanEur, true));
      marks.push(
        Plot.lineY(avgCurve, { x: 'x', y: 'p', stroke: C.s[3], strokeWidth: 1.6, strokeDasharray: '4,4' }),
        Plot.lineY(tan(meanEur, true), { x: 'x', y: 'p', stroke: C.s[3], strokeWidth: 2.4 }),
        Plot.dot([{ x: meanEur, p: pm }], { x: 'x', y: 'p', r: 6, fill: C.s[3], symbol: 'diamond' }),
        Plot.text([{ x: meanEur, p: pm }], { x: 'x', y: 'p', text: () => `"Average client" at the mean rate, ${meanEur.toFixed(2)}%`, dy: -16, fill: C.s[3], fontSize: 12, fontWeight: 650, stroke: 'var(--surface)', strokeWidth: 3, paintOrder: 'stroke' }),
      );
    }
    marks.push(
      Plot.lineY(tan(x0), { x: 'x', y: 'p', stroke: C.forecast, strokeWidth: 2.5 }),
      Plot.dot([{ x: x0, p: at.p }], { x: 'x', y: 'p', r: 7, fill: C.forecast, stroke: 'var(--surface)', strokeWidth: 2 }),
      Plot.text([{ x: x0, p: at.p }], { x: 'x', y: 'p', text: () => `slope ${(100 * at.slope).toFixed(1)} pp per point`, dx: 12, dy: -14, textAnchor: 'start', fill: C.forecast, fontSize: 12, fontWeight: 700, stroke: 'var(--surface)', strokeWidth: 3, paintOrder: 'stroke' }),
    );
    const chart = Plot.plot({
      width: W, height: H, marginLeft: 48, marginRight: 16, marginTop: 16, marginBottom: 38, style: plotStyle(),
      x: { domain: [0.4, 5.4], label: '3-month Euribor rate on the day of the call (%)', labelAnchor: 'center', labelArrow: 'none' },
      y: { domain: [0, top], grid: true, label: null, tickFormat: (d: number) => `${Math.round(d * 100)}%` },
      marks,
    });
    chart.setAttribute('aria-label', `Fitted probability of a yes against Euribor for the selected client. At ${x0.toFixed(2)} percent the probability is ${(100 * at.p).toFixed(1)} percent and the slope is ${(100 * at.slope).toFixed(1)} percentage points per point.`);
    el.replaceChildren(chart);
  }
  $effect(() => { x0; prof; compare; ready; draw(); });
  onMount(() => { load(); return watchLayout(el, draw); });
</script>

<Explorable title="The slope of an S-curve depends on where you stand" caption="The cyan curve is the chapter's five-fact logit (refitted in your browser on the 2,882 training clients) for a 40-year-old reached on a mobile phone on the first call, as Euribor varies. Move the Euribor slider: the violet tangent's slope is the <b>marginal effect</b> b·p(1 − p) at that rate. The same coefficient gives a steep slope where p is near 50% and a shallow one where p is small. Grey bars show that the calls happened at two very different rate levels, near 1% and near 5%, with almost nothing in between; switch on the averages to see why the effect at the mean describes a client who barely exists.">
  {#snippet controls()}
    <label class="sl">Euribor <input type="range" min="0.6" max="5.1" step="0.01" bind:value={x0} aria-valuetext={`${x0} percent`} /> <b>{x0.toFixed(2)}%</b></label>
    <div class="seg" role="group" aria-label="Client profile">
      {#each PROFILES as p}<button class:on={prof === p.k} aria-pressed={prof === p.k} onclick={() => (prof = p.k)}>{p.label}</button>{/each}
    </div>
    <div class="seg" role="group" aria-label="Show averages">
      <button class:on={!compare} aria-pressed={!compare} onclick={() => (compare = false)}>Tangent only</button>
      <button class:on={compare} aria-pressed={compare} onclick={() => (compare = true)}>Compare AME and MEM</button>
    </div>
  {/snippet}
  {#snippet aside()}
    <div class="side" aria-live="polite">
      <div class="stat"><span class="stat-v">{(100 * at.p).toFixed(1)}%</span><span class="stat-l">chance of a yes at {x0.toFixed(2)}%</span></div>
      <div class="stat"><span class="stat-v">{(100 * at.slope).toFixed(1)} pp</span><span class="stat-l">marginal effect here: the tangent's slope, per point of Euribor (coefficient b = {bEur.toFixed(3)})</span></div>
      <p class="note">Exact change if Euribor rose a full point from here: <b>{(100 * at.exact).toFixed(1)} pp</b>. The tangent is a local approximation.</p>
      {#if compare && ready}
        <div class="cmp">
          <div><span class="tag ame">AME</span> <b>{(100 * ame).toFixed(2)} pp</b> <span class="l">average of all 2,882 training clients' own slopes (they range from {(100 * meMin).toFixed(1)} to {(100 * meMax).toFixed(1)})</span></div>
          <div><span class="tag mem">MEM</span> <b>{(100 * mem).toFixed(2)} pp</b> <span class="l">slope for one "average client" with every fact at its mean</span></div>
          <p class="note">The mean rate is {meanEur.toFixed(2)}%, yet only <b>{gap}</b> of {n.toLocaleString()} calls were made at rates between 2% and 4%, and no real client is 3.6% "past success". Report the AME.</p>
        </div>
      {/if}
    </div>
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 280px; }
  .side { display: grid; gap: .8rem; font-size: .84rem; }
  .note { margin: 0; color: var(--muted); font-size: .78rem; }
  .cmp { display: grid; gap: .45rem; border-top: 1px dashed var(--border); padding-top: .7rem; font-variant-numeric: tabular-nums; }
  .cmp .l { display: block; color: var(--muted); font-size: .76rem; }
  .tag { font-size: .72rem; font-weight: 700; padding: .05rem .35rem; border-radius: 4px; }
  .tag.ame { background: color-mix(in srgb, var(--c-fitted) 20%, transparent); color: var(--c-fitted); }
  .tag.mem { background: color-mix(in srgb, var(--c-s4) 22%, transparent); color: var(--c-s4); }
</style>
