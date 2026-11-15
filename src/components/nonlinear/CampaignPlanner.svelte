<script lang="ts">
  // Campaign planner: rank 1,237 held-out clients by predicted probability and decide how far down the list to call.
  // One slider (share called) drives the confusion matrix, metrics, ROC point, gain/lift and profit.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import data from './nldata.json';

  const T = data.bank.test as { p: number[]; pd: number[]; y: number[] };
  const COST = 5, VALUE = 50;
  const n = T.y.length, nPos = T.y.reduce((s, v) => s + v, 0), nNeg = n - nPos;

  let share = $state(20);
  let view = $state('grid');
  let model = $state('honest');
  let el: HTMLDivElement;

  function prep(p: number[]) {
    const o = p.map((_, i) => i).sort((a, b) => p[b] - p[a] || a - b);
    const cumTP = [0]; o.forEach((i, k) => cumTP.push(cumTP[k] + T.y[i]));
    let auc = 0; // trapezoid over ROC
    for (let k = 1; k <= n; k++) { const tp = cumTP[k] / nPos, fp = (k - cumTP[k]) / nNeg, tp0 = cumTP[k - 1] / nPos, fp0 = (k - 1 - cumTP[k - 1]) / nNeg; auc += (fp - fp0) * (tp + tp0) / 2; }
    return { p, o, cumTP, auc };
  }
  const M = { honest: prep(T.p), leak: prep(T.pd) };

  const cur = $derived(M[model as 'honest' | 'leak']);
  const k = $derived(Math.max(1, Math.round((share / 100) * n)));
  const st = $derived.by(() => {
    const TP = cur.cumTP[k], FP = k - TP, FN = nPos - TP, TN = nNeg - FP;
    const precision = TP / k, recall = TP / nPos, specificity = TN / nNeg;
    return { TP, FP, FN, TN, accuracy: (TP + TN) / n, precision, recall, specificity, F1: TP ? (2 * precision * recall) / (precision + recall) : 0,
      thr: cur.p[cur.o[k - 1]], profit: VALUE * TP - COST * k, lift: recall / (k / n) };
  });
  const best = $derived.by(() => {
    let bk = 1, bv = -Infinity;
    for (let j = 1; j <= n; j++) { const v = VALUE * cur.cumTP[j] - COST * j; if (v > bv) { bv = v; bk = j; } }
    return { k: bk, profit: bv };
  });
  const allProfit = VALUE * nPos - COST * n;
  const alwaysNo = nNeg / n;
  const pct = (v: number, d = 1) => `${(100 * v).toFixed(d)}%`;

  function draw() {
    if (!el) return;
    const W = el.clientWidth;
    let chart: any;
    const base = { width: W, style: plotStyle(), marginLeft: 52, marginRight: 20, marginTop: 18, marginBottom: 40 };
    if (view === 'grid') {
      const cols = W < 560 ? 30 : 50, rowsN = Math.ceil(n / cols);
      const cell = Math.min(14, (W - 20) / cols);
      const d = cur.o.map((i, r) => {
        const called = r < k, buyer = T.y[i] === 1;
        return { cx: r % cols, cy: Math.floor(r / cols), cls: called ? (buyer ? 'TP' : 'FP') : buyer ? 'FN' : 'TN', p: cur.p[i], r: r + 1 };
      });
      const col: Record<string, string> = { TP: C.good, FP: C.actual, FN: C.danger, TN: C.muted };
      chart = Plot.plot({
        ...base, height: rowsN * cell + 30, marginLeft: 4, marginRight: 4, marginTop: 4, marginBottom: 4,
        x: { axis: null, domain: [-0.5, cols - 0.5] }, y: { axis: null, domain: [rowsN - 0.5, -0.5] },
        marks: [
          Plot.dot(d.filter((r) => r.cls === 'TN' || r.cls === 'FP'), { x: 'cx', y: 'cy', symbol: 'square', r: cell * 0.3, fill: (r: any) => col[r.cls], fillOpacity: (r: any) => (r.cls === 'TN' ? 0.25 : 0.75) }),
          Plot.dot(d.filter((r) => r.cls === 'TP' || r.cls === 'FN'), { x: 'cx', y: 'cy', symbol: 'circle', r: cell * 0.42, fill: (r: any) => col[r.cls], stroke: 'var(--surface)', strokeWidth: 1 }),
          Plot.tip(d, Plot.pointer({ x: 'cx', y: 'cy', title: (r: any) => `Rank ${r.r} of ${n}\nPredicted ${pct(r.p)}\n${{ TP: 'Called, subscribed', FP: 'Called, said no', FN: 'Not called, would have subscribed', TN: 'Not called, would have said no' }[r.cls as 'TP']}` })),
        ],
      });
    } else if (view === 'roc') {
      const pts = Array.from({ length: n + 1 }, (_, j) => ({ fpr: (j - cur.cumTP[j]) / nNeg, tpr: cur.cumTP[j] / nPos }));
      chart = Plot.plot({
        ...base, height: Math.min(380, W * 0.6),
        x: { domain: [0, 1], label: 'False-positive rate: share of non-buyers called', labelAnchor: 'center', labelArrow: 'none', tickFormat: (d: number) => pct(d, 0) },
        y: { domain: [0, 1], grid: true, label: null, tickFormat: (d: number) => pct(d, 0) },
        marks: [
          Plot.line([[0, 0], [1, 1]], { stroke: C.muted, strokeDasharray: '4,4' }),
          Plot.text([[0.62, 0.55]], { text: () => 'Coin flip (AUC 0.5)', fill: C.muted, fontSize: 12, rotate: -38 * Math.min(1, W / 600) }),
          Plot.areaY(pts, { x: 'fpr', y: 'tpr', fill: C.fitted, fillOpacity: 0.1, curve: 'step-after' }),
          Plot.line(pts, { x: 'fpr', y: 'tpr', stroke: C.fitted, strokeWidth: 2.5 }),
          Plot.dot([pts[k]], { x: 'fpr', y: 'tpr', r: 7, fill: C.forecast, stroke: 'var(--surface)', strokeWidth: 2 }),
          Plot.text([pts[k]], { x: 'fpr', y: 'tpr', text: () => `Call top ${share}%`, dx: 10, dy: 14, textAnchor: 'start', fill: C.forecast, fontWeight: 700, fontSize: 12, stroke: 'var(--surface)', strokeWidth: 3, paintOrder: 'stroke' }),
          Plot.text([[0.98, 0.08]], { text: () => `AUC = ${cur.auc.toFixed(3)}  ·  Gini = ${(2 * cur.auc - 1).toFixed(3)}`, textAnchor: 'end', fill: C.fitted, fontWeight: 700, fontSize: 13 }),
        ],
      });
    } else if (view === 'gain') {
      const step = Math.max(1, Math.floor(n / 200));
      const g = Array.from({ length: n + 1 }, (_, j) => j).filter((j) => j % step === 0 || j === n).map((j) => ({ x: j / n, gain: cur.cumTP[j] / nPos }));
      chart = Plot.plot({
        ...base, height: Math.min(380, W * 0.6),
        x: { domain: [0, 1], label: 'Share of the list called, best prospects first', labelAnchor: 'center', labelArrow: 'none', tickFormat: (d: number) => pct(d, 0) },
        y: { domain: [0, 1], grid: true, label: null, tickFormat: (d: number) => pct(d, 0) },
        marks: [
          Plot.line([[0, 0], [nPos / n, 1], [1, 1]], { stroke: C.good, strokeDasharray: '2,3', strokeOpacity: 0.8 }),
          Plot.text([[nPos / n, 1]], { text: () => 'Perfect ranking', dx: 6, dy: 12, textAnchor: 'start', fill: C.good, fontSize: 12 }),
          Plot.line([[0, 0], [1, 1]], { stroke: C.muted, strokeDasharray: '4,4' }),
          Plot.text([[0.7, 0.62]], { text: () => 'Random calling', fill: C.muted, fontSize: 12 }),
          Plot.line(g, { x: 'x', y: 'gain', stroke: C.fitted, strokeWidth: 2.5 }),
          Plot.ruleX([k / n], { stroke: C.forecast, strokeDasharray: '3,3' }),
          Plot.dot([{ x: k / n, gain: st.recall }], { x: 'x', y: 'gain', r: 7, fill: C.forecast, stroke: 'var(--surface)', strokeWidth: 2 }),
          Plot.text([{ x: k / n, gain: st.recall }], { x: 'x', y: 'gain', text: () => `${pct(st.recall, 0)} of buyers reached · lift ${st.lift.toFixed(2)}`, dx: 10, dy: 16, textAnchor: 'start', fill: C.forecast, fontWeight: 700, fontSize: 12, stroke: 'var(--surface)', strokeWidth: 3, paintOrder: 'stroke' }),
        ],
      });
    } else {
      const step = Math.max(1, Math.floor(n / 250));
      const pr = Array.from({ length: n + 1 }, (_, j) => j).filter((j) => j % step === 0 || j === n).map((j) => ({ x: j / n, v: VALUE * cur.cumTP[j] - COST * j }));
      chart = Plot.plot({
        ...base, height: Math.min(360, W * 0.55), marginLeft: 64,
        x: { domain: [0, 1], label: 'Share of the list called, best prospects first', labelAnchor: 'center', labelArrow: 'none', tickFormat: (d: number) => pct(d, 0) },
        y: { grid: true, label: null, tickFormat: (d: number) => `$${d.toLocaleString()}` },
        marks: [
          Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
          Plot.areaY(pr, { x: 'x', y: 'v', fill: C.good, fillOpacity: 0.08 }),
          Plot.line(pr, { x: 'x', y: 'v', stroke: C.good, strokeWidth: 2.5 }),
          Plot.dot([{ x: best.k / n, v: best.profit }], { x: 'x', y: 'v', r: 5, fill: C.good, symbol: 'diamond' }),
          Plot.text([{ x: best.k / n, v: best.profit }], { x: 'x', y: 'v', text: () => `Best: call ${pct(best.k / n, 0)} → $${best.profit.toLocaleString()}`, dy: -14, fill: C.good, fontWeight: 700, fontSize: 12, stroke: 'var(--surface)', strokeWidth: 3, paintOrder: 'stroke' }),
          Plot.dot([{ x: k / n, v: st.profit }], { x: 'x', y: 'v', r: 7, fill: C.forecast, stroke: 'var(--surface)', strokeWidth: 2 }),
          Plot.text([{ x: 1, v: allProfit }], { x: 'x', y: 'v', text: () => `Call everyone: $${allProfit.toLocaleString()}`, textAnchor: 'end', dy: -12, fill: C.muted, fontSize: 12 }),
        ],
      });
    }
    chart.setAttribute?.('aria-label', `Calling the top ${share} percent (${k} clients) reaches ${st.TP} of ${nPos} subscribers; precision ${pct(st.precision)}, recall ${pct(st.recall)}, profit $${st.profit}.`);
    el.replaceChildren(chart);
  }
  $effect(() => { share; view; model; draw(); });
  onMount(() => watchLayout(el, draw));
</script>

<Explorable title="A call budget is a threshold: plan the next campaign" caption={`The 1,237 test clients, ranked by the logit fitted on the other 2,882. Calling the top X% of the list is the same as predicting "yes" for everyone above a probability threshold (shown in the panel). <b>Who gets called</b>: circles are clients who subscribed, squares those who did not; green = reached buyer, gold = wasted call, red = missed buyer. <b>Profit</b> assumes, for illustration, $${COST} per call and $${VALUE} of value per new deposit. Then flip on <b>call duration</b> and watch every metric jump: that model uses information you only have after the call. Data: UCI Bank Marketing (Moro et al. 2014).`}>
  {#snippet controls()}
    <label class="sl">Call the top <input type="range" min="1" max="100" step="1" bind:value={share} aria-valuetext={`${share} percent of clients`} /> <b>{share}%</b></label>
    <div class="seg" role="group" aria-label="View">
      <button class:on={view === 'grid'} aria-pressed={view === 'grid'} onclick={() => (view = 'grid')}>Who gets called</button>
      <button class:on={view === 'roc'} aria-pressed={view === 'roc'} onclick={() => (view = 'roc')}>ROC</button>
      <button class:on={view === 'gain'} aria-pressed={view === 'gain'} onclick={() => (view = 'gain')}>Gains &amp; lift</button>
      <button class:on={view === 'profit'} aria-pressed={view === 'profit'} onclick={() => (view = 'profit')}>Profit</button>
    </div>
    <div class="seg" role="group" aria-label="Model">
      <button class:on={model === 'honest'} aria-pressed={model === 'honest'} onclick={() => (model = 'honest')}>Before-call facts</button>
      <button class:on={model === 'leak'} aria-pressed={model === 'leak'} onclick={() => (model = 'leak')} class:leak={model === 'leak'}>+ call duration (leak)</button>
    </div>
  {/snippet}
  {#snippet aside()}
    <div class="side" aria-live="polite">
      <p class="thr">Calling <b>{k}</b> clients = predicting "yes" when p ≥ <b>{pct(st.thr)}</b></p>
      <table class="cm" aria-label="Confusion matrix">
        <thead><tr><th></th><th>Subscribed</th><th>Said no</th></tr></thead>
        <tbody>
          <tr><th>Called</th><td class="tp">{st.TP}</td><td class="fp">{st.FP}</td></tr>
          <tr><th>Not called</th><td class="fn">{st.FN}</td><td class="tn">{st.TN}</td></tr>
        </tbody>
      </table>
      <dl class="mx">
        <dt>Accuracy</dt><dd class:warn={st.accuracy < alwaysNo}>{pct(st.accuracy)}</dd>
        <dt>Precision</dt><dd>{pct(st.precision)}</dd>
        <dt>Recall</dt><dd>{pct(st.recall)}</dd>
        <dt>Specificity</dt><dd>{pct(st.specificity)}</dd>
        <dt>F1</dt><dd>{st.F1.toFixed(3)}</dd>
        <dt>Profit</dt><dd class:good={st.profit > 0}>${st.profit.toLocaleString()}</dd>
      </dl>
      <p class="para"><b>Accuracy paradox:</b> calling nobody is {pct(alwaysNo)} accurate and earns $0.{st.accuracy < alwaysNo ? ` Your plan is less "accurate" (${pct(st.accuracy)}) yet finds ${st.TP} subscribers.` : ''}</p>
      {#if model === 'leak'}<p class="leakmsg">AUC {M.leak.auc.toFixed(3)} vs {M.honest.auc.toFixed(3)}. Too good to be true: you cannot know a call's length before you make it.</p>{/if}
    </div>
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 300px; }
  .side { display: grid; gap: .7rem; font-size: .82rem; }
  .thr { margin: 0; color: var(--text-2); font-variant-numeric: tabular-nums; }
  .cm { margin: 0; font-size: .8rem; font-variant-numeric: tabular-nums; }
  .cm th, .cm td { padding: .3rem .4rem; text-align: center; }
  .cm td { font-weight: 700; }
  .tp { color: var(--good); } .fp { color: var(--c-actual); } .fn { color: var(--danger); } .tn { color: var(--muted); }
  .mx { display: grid; grid-template-columns: auto 1fr; gap: .2rem .8rem; margin: 0; font-variant-numeric: tabular-nums; }
  .mx dt { color: var(--muted); } .mx dd { margin: 0; font-weight: 650; color: var(--text); text-align: right; }
  .mx dd.warn { color: var(--warm); } .mx dd.good { color: var(--good); }
  .para { margin: 0; color: var(--muted); font-size: .78rem; }
  .leakmsg { margin: 0; color: var(--danger); font-size: .8rem; font-weight: 600; }
  .seg button.leak { color: var(--danger) !important; }
</style>
