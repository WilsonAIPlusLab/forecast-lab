<script lang="ts">
  // Client scorecard: one client's predicted probability built up as a "log-odds waterfall".
  // Start from a reference client (40 years old, mobile phone, first call, never contacted, Euribor 4.9%: 5.6%),
  // add each fact's contribution b × (this client's value − the reference value) on the log-odds scale,
  // then translate the total back into a probability, a natural frequency ("out of 100 clients like this")
  // and the expected value of one phone call. Coefficients: the chapter's five-fact logit on 2,882 training clients
  // (nldata.json, written by src/labs/nonlinear/make_data.R); clients: the 1,237 test clients (same split as the labs).
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { BASE } from '../../lib/runtime/status';
  import { loadCSV, plogis, type Row } from './nlmath';
  import data from './nldata.json';

  const b = data.bank.coef as Record<string, number>;
  const COST = 5;
  interface Client { age: number; tel: number; campaign: number; pout: string; eur: number; job?: string; yes?: number; tag: string }
  const REF: Client = { age: 40, tel: 0, campaign: 1, pout: 'nonexistent', eur: 4.9, tag: 'Reference client (made up)' };

  let test: Client[] = $state.raw([]);
  let order: number[] = [];
  let k = 0;
  let pick = $state('ref');
  let client: Client = $state.raw(REF);
  let value = $state(50);
  let el: HTMLDivElement;

  const toClient = (r: Row, tag: string): Client => ({
    age: Number(r.age), tel: r.contact === 'telephone' ? 1 : 0, campaign: Number(r.campaign), pout: String(r.poutcome),
    eur: Number(r.euribor3m), job: String(r.job), yes: r.y === 'yes' ? 1 : 0, tag,
  });
  const etaOf = (c: Client) => b['(Intercept)'] + b.age * c.age + b.contacttelephone * c.tel + b.campaign * c.campaign
    + (c.pout === 'failure' ? b.poutcomefailure : 0) + (c.pout === 'success' ? b.poutcomesuccess : 0) + b.euribor3m * c.eur;

  const presets = $derived.by(() => {
    if (!test.length) return {} as Record<string, Client>;
    const best = test.reduce((m, c) => (etaOf(c) > etaOf(m) ? c : m), test[0]);
    const land = test.find((c) => c.tel === 1 && c.campaign >= 4 && c.pout === 'nonexistent') ?? test[0];
    const lowRate = test.find((c) => c.tel === 0 && c.eur < 1.5 && c.pout === 'nonexistent' && c.campaign === 1) ?? test[0];
    return { best: { ...best, tag: 'Best prospect on the test list' }, land: { ...land, tag: 'Landline client, called many times' }, low: { ...lowRate, tag: 'First call, low-rate period' } };
  });

  function choose(key: string) {
    pick = key;
    if (key === 'ref') client = REF;
    else if (key === 'next') { k = (k + 1) % order.length; client = { ...test[order[k]], tag: `Test client #${order[k] + 1} of ${test.length.toLocaleString()}` }; }
    else client = presets[key] ?? REF;
  }

  async function load() {
    const rows = await loadCSV(BASE, 'bank_marketing.csv');
    // same stratified split as the labs: position within outcome class, positions 0-2 of every 10 = test
    const seen: Record<string, number> = {};
    const t = rows.filter((r) => { const key = String(r.y); const pos = (seen[key] = (seen[key] ?? -1) + 1); return pos % 10 < 3; });
    test = t.map((r) => toClient(r, ''));
    // fixed pseudo-random walk through the test list (same order for every reader)
    order = test.map((_, i) => i).sort((i, j) => ((i * 7919) % 1237) - ((j * 7919) % 1237));
  }

  const POUT: Record<string, string> = { nonexistent: 'never contacted', failure: 'previous campaign failed', success: 'previous campaign succeeded' };
  const steps = $derived.by(() => {
    const c = client;
    const pIdx = (p: string) => (p === 'failure' ? b.poutcomefailure : p === 'success' ? b.poutcomesuccess : 0);
    const raw = [
      { key: 'Age', val: `${c.age} years`, ref: '40 years', d: b.age * (c.age - REF.age) },
      { key: 'Phone', val: c.tel ? 'landline' : 'mobile', ref: 'mobile', d: b.contacttelephone * c.tel },
      { key: 'Calls', val: `${c.campaign} this campaign`, ref: '1 (first call)', d: b.campaign * (c.campaign - REF.campaign) },
      { key: 'Past campaign', val: POUT[c.pout], ref: 'never contacted', d: pIdx(c.pout) },
      { key: 'Euribor', val: `${c.eur.toFixed(2)}%`, ref: '4.90%', d: b.euribor3m * (c.eur - REF.eur) },
    ];
    let at = etaOf(REF);
    return raw.map((s) => { const from = at; at += s.d; return { ...s, from, to: at }; });
  });
  const eta0 = etaOf(REF);
  const eta = $derived(etaOf(client));
  const p = $derived(plogis(eta));
  const ev = $derived(p * value - COST);
  const per100 = $derived(Math.round(100 * p));

  const PT = [0.01, 0.02, 0.05, 0.1, 0.2, 0.3, 0.5, 0.7, 0.8, 0.9];
  const lo = (q: number) => Math.log(q / (1 - q));
  function draw() {
    if (!el) return;
    const W = el.clientWidth, narrow = W < 520;
    if (W < 200) return; // skip transient zero-width layouts
    const pt = narrow ? [0.02, 0.05, 0.1, 0.3, 0.5, 0.8] : PT;
    const xs = [eta0, ...steps.map((s) => s.to), lo(0.02), lo(0.3)];
    const x0 = Math.min(...xs) - 0.4, x1 = Math.max(...xs) + 0.5;
    const rowsY = ['Reference client', ...steps.map((s) => s.key), 'This client'];
    const bars = steps.map((s) => ({ ...s, y: s.key }));
    const marks: any[] = [
      Plot.ruleX(pt.map(lo).filter((v) => v > x0 && v < x1), { stroke: C.border, strokeDasharray: '2,3' }),
      Plot.axisX(pt.map(lo).filter((v) => v > x0 && v < x1), { anchor: 'top', tickFormat: (v: number) => `${Math.round(100 * plogis(v))}%`, label: 'Probability of a yes', labelAnchor: 'center', labelArrow: 'none', fontSize: 12 }),
      Plot.axisX({ anchor: 'bottom', label: narrow ? 'Log-odds (where the bars add up)' : 'Log-odds (the scale on which the model adds things up)', labelAnchor: 'center', labelArrow: 'none', ticks: narrow ? 4 : 8 }),
      Plot.barX(bars, { x1: 'from', x2: 'to', y: 'y', fill: (d: any) => (d.d >= 0 ? C.good : C.danger), fillOpacity: 0.8, insetTop: 4, insetBottom: 4 }),
      Plot.ruleX([eta0], { y1: rowsY[0], y2: rowsY[1], stroke: C.muted, strokeDasharray: '3,3' }),
      Plot.dot([{ x: eta0, y: rowsY[0] }], { x: 'x', y: 'y', r: 7, fill: C.actual, stroke: C.surface, strokeWidth: 2 }),
      Plot.dot([{ x: eta, y: 'This client' }], { x: 'x', y: 'y', r: 8, fill: C.forecast, stroke: C.surface, strokeWidth: 2 }),
      Plot.text(bars.filter((d) => Math.abs(d.d) > 0.0005), { x: (d: any) => Math.max(d.from, d.to), y: 'y', text: (d: any) => `${d.d >= 0 ? '+' : '−'}${Math.abs(d.d).toFixed(2)}`, dx: 6, textAnchor: 'start', fill: C.text2, fontSize: 12, fontWeight: 650 }),
      Plot.text(bars.filter((d) => Math.abs(d.d) <= 0.0005), { x: 'from', y: 'y', text: () => 'same as reference', dx: 8, textAnchor: 'start', fill: C.muted, fontSize: 12 }),
      Plot.text([{ x: eta0, y: rowsY[0] }], { x: 'x', y: 'y', text: () => `${(100 * plogis(eta0)).toFixed(1)}%`, dx: 12, textAnchor: 'start', fill: C.text2, fontSize: 12, fontWeight: 650 }),
      Plot.text([{ x: eta, y: 'This client' }], { x: 'x', y: 'y', text: () => `${(100 * p).toFixed(1)}%`, dx: eta > x1 - 1.2 ? -12 : 12, textAnchor: eta > x1 - 1.2 ? 'end' : 'start', fill: C.forecast, fontSize: 13, fontWeight: 750, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
    ];
    const chart = Plot.plot({
      width: W, height: 320, marginLeft: narrow ? 92 : 118, marginRight: 24, marginTop: 44, marginBottom: 42, style: plotStyle(),
      x: { domain: [x0, x1] }, y: { domain: rowsY, label: null, tickSize: 0, padding: 0.15 },
      marks,
    });
    chart.setAttribute('aria-label', `Log-odds waterfall. The reference client has a ${(100 * plogis(eta0)).toFixed(1)} percent chance of a yes. ` +
      steps.map((s) => `${s.key}: ${s.val}, ${s.d >= 0 ? 'adds' : 'subtracts'} ${Math.abs(s.d).toFixed(2)}`).join('; ') + `. This client: ${(100 * p).toFixed(1)} percent.`);
    el.replaceChildren(chart);
  }
  $effect(() => { client; draw(); });
  onMount(() => { load(); return watchLayout(el, draw); });
</script>

<Explorable title="What the model says about one client, fact by fact" caption="Start from a made-up <b>reference client</b> (40 years old, mobile phone, first call, never contacted before, Euribor 4.9%), whom the model gives a 5.6% chance. Each bar is one fact where the chosen client differs from the reference: its coefficient times the difference (green raises the chance, red lowers it). Bars add up on the <b>log-odds</b> scale (bottom axis); the top axis reads the same positions as probabilities, so equal bar lengths are equal odds ratios but not equal percentage points. The panel turns the result into words a manager can use. Coefficients: the chapter's five-fact logit fitted on 2,882 training clients; clients: the 1,237 test clients. Data: UCI Bank Marketing (Moro et al. 2014).">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Choose a client">
      <button class:on={pick === 'ref'} aria-pressed={pick === 'ref'} onclick={() => choose('ref')}>Reference</button>
      <button class:on={pick === 'best'} aria-pressed={pick === 'best'} onclick={() => choose('best')} disabled={!test.length}>Best prospect</button>
      <button class:on={pick === 'low'} aria-pressed={pick === 'low'} onclick={() => choose('low')} disabled={!test.length}>Low-rate period</button>
      <button class:on={pick === 'land'} aria-pressed={pick === 'land'} onclick={() => choose('land')} disabled={!test.length}>Landline, many calls</button>
      <button class:on={pick === 'next'} aria-pressed={pick === 'next'} onclick={() => choose('next')} disabled={!test.length}>Next test client →</button>
    </div>
    <label class="sl">Value of a deposit <input type="range" min="20" max="150" step="5" bind:value={value} aria-valuetext={`${value} dollars`} /> <b>${value}</b></label>
  {/snippet}
  {#snippet aside()}
    <div class="side" aria-live="polite">
      <div class="eyebrow">{client.tag}{client.job ? ` · ${client.job}` : ''}</div>
      <div class="stat"><span class="stat-v">{(100 * p).toFixed(1)}%</span><span class="stat-l">chance of a yes (log-odds {eta.toFixed(2)}, odds {p >= 0.5 ? `${(p / (1 - p)).toFixed(2)} to 1` : `1 to ${((1 - p) / p).toFixed(1)}`})</span></div>
      <p class="words">In words: <b>out of 100 clients like this one, about {per100} would say yes</b>{per100 === 0 ? ' (fewer than 1)' : ''}. The base rate is about 11 in 100.</p>
      <p class="words">One call costs ${COST}; a deposit is worth ${value}. Expected value of calling: {(100 * p).toFixed(1)}% × ${value} − ${COST} = <b class="nw" class:pos={ev >= 0} class:neg={ev < 0}>{ev >= 0 ? '+' : '−'}${Math.abs(ev).toFixed(2)}</b>. Decision: <b>{ev >= 0 ? 'call' : 'skip'}</b> (call when the chance is above {(100 * COST / value).toFixed(1)}%).</p>
      {#if client.yes !== undefined}<p class="note">What actually happened: this client <b>{client.yes ? 'subscribed' : 'said no'}</b>. One outcome cannot prove a probability right or wrong; only many clients can.</p>{/if}
    </div>
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 320px; }
  .side { display: grid; gap: .7rem; font-size: .84rem; }
  .eyebrow { font-size: .74rem; font-weight: 700; color: var(--muted); text-transform: uppercase; letter-spacing: .04em; }
  .words { margin: 0; color: var(--text-2); line-height: 1.5; }
  .note { margin: 0; color: var(--muted); font-size: .78rem; }
  .nw { white-space: nowrap; }
  .pos { color: var(--good); }
  .neg { color: var(--danger); }
</style>
