<script lang="ts">
  // Odds translator: probability, odds and log-odds as three linked number lines,
  // plus a coefficient reader that applies the fitted logit's odds ratios to a starting probability.
  import { onMount } from 'svelte';
  import * as d3 from 'd3';
  import Explorable from '../Explorable.svelte';
  import { C, watchLayout } from '../../lib/viz/theme';
  import data from './nldata.json';

  const b = data.bank.coef as Record<string, number>;
  const PRED = [
    { k: 'poutcomesuccess', label: 'Past campaign: success', unit: 'switch from "never contacted" to "past success"', per: 1, unitWord: '' },
    { k: 'euribor3m', label: 'Euribor +1 point', unit: 'one percentage point higher Euribor', per: 1, unitWord: 'point' },
    { k: 'campaign', label: 'One more call', unit: 'one more call to this client in this campaign', per: 1, unitWord: 'call' },
    { k: 'contacttelephone', label: 'Landline, not mobile', unit: 'reached on a landline instead of a mobile phone', per: 1, unitWord: '' },
    { k: 'age', label: '10 years older', unit: 'ten years older', per: 10, unitWord: 'decade' },
  ];
  let p0 = $state(5.6);
  let pk = $state('poutcomesuccess');
  let units = $state(0);
  let el: HTMLDivElement;

  const pred = $derived(PRED.find((x) => x.k === pk)!);
  const beta = $derived(b[pk] * pred.per);
  const OR = $derived(Math.exp(beta));
  const binary = $derived(pk === 'poutcomesuccess' || pk === 'contacttelephone');
  const maxUnits = $derived(binary ? 1 : 5);
  $effect(() => { if (units > maxUnits) units = maxUnits; });
  const s = $derived.by(() => {
    const p = p0 / 100, o = p / (1 - p), lo = Math.log(o);
    const lo1 = lo + units * beta, o1 = Math.exp(lo1), p1 = o1 / (1 + o1);
    return { p, o, lo, p1, o1, lo1 };
  });

  const fmtOdds = (o: number) => (o >= 1 ? `${o.toFixed(o < 10 ? 2 : 1)} to 1` : `1 to ${(1 / o).toFixed(1 / o < 10 ? 2 : 1)}`);
  const pct = (p: number) => `${(100 * p).toFixed(p < 0.1 || p > 0.9 ? 1 : 1)}%`;

  function draw() {
    if (!el) return;
    const W = el.clientWidth, H = 300, ml = 120, mr = 24;
    const xP = d3.scaleLinear().domain([0, 1]).range([ml, W - mr]);
    const xO = d3.scaleLog().domain([0.005, 200]).range([ml, W - mr]);
    const xL = d3.scaleLinear().domain([-5.3, 5.3]).range([ml, W - mr]);
    const rows = [
      { y: 50, name: 'Probability', sub: 'p', scale: xP, v: s.p, v1: s.p1, ticks: [0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1], tf: (t: number) => `${Math.round(t * 100)}%` },
      { y: 150, name: 'Odds', sub: 'p / (1 − p)', scale: xO, v: s.o, v1: s.o1, ticks: [0.01, 0.1, 0.25, 1, 4, 10, 100], tf: (t: number) => (t >= 1 ? `${t}:1` : `1:${Math.round(1 / t)}`) },
      { y: 250, name: 'Log-odds', sub: 'log(odds)', scale: xL, v: s.lo, v1: s.lo1, ticks: [-5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5], tf: (t: number) => `${t}` },
    ];
    const svg = d3.create('svg').attr('width', W).attr('height', H).attr('role', 'img')
      .attr('aria-label', `Starting probability ${pct(s.p)} is odds ${fmtOdds(s.o)} and log-odds ${s.lo.toFixed(2)}. After ${units} unit(s) of the selected change the probability is ${pct(s.p1)}.`);
    // the translation itself: probability deciles mapped through odds onto log-odds
    const dec = d3.range(0.05, 1, 0.05);
    svg.append('g').selectAll('path').data(dec).join('path')
      .attr('d', (q) => `M${xP(q)},${58} C${xP(q)},${100} ${xO(q / (1 - q))},${100} ${xO(q / (1 - q))},${142} M${xO(q / (1 - q))},${158} C${xO(q / (1 - q))},${200} ${xL(Math.log(q / (1 - q)))},${200} ${xL(Math.log(q / (1 - q)))},${242}`)
      .attr('fill', 'none').attr('stroke', C.muted).attr('stroke-opacity', 0.22).attr('stroke-width', 1);
    for (const r of rows) {
      const g = svg.append('g');
      g.append('line').attr('x1', ml).attr('x2', W - mr).attr('y1', r.y).attr('y2', r.y).attr('stroke', C.borderStrong).attr('stroke-width', 1.5);
      g.selectAll('line.t').data(r.ticks).join('line').attr('x1', (t) => r.scale(t)).attr('x2', (t) => r.scale(t)).attr('y1', r.y - 4).attr('y2', r.y + 4).attr('stroke', C.muted);
      g.selectAll('text.t').data(r.ticks).join('text').attr('x', (t) => r.scale(t)).attr('y', r.y + 20).attr('text-anchor', 'middle').attr('font-size', 12).attr('fill', C.muted).text((t) => r.tf(t));
      g.append('text').attr('x', 8).attr('y', r.y - 2).attr('font-size', 13).attr('font-weight', 700).attr('fill', C.text).text(r.name);
      g.append('text').attr('x', 8).attr('y', r.y + 14).attr('font-size', 12).attr('fill', C.muted).text(r.sub);
      const cx = Math.max(ml, Math.min(W - mr, r.scale(r.v))), cx1 = Math.max(ml, Math.min(W - mr, r.scale(r.v1)));
      if (units > 0 && Math.abs(cx1 - cx) > 2) {
        g.append('line').attr('x1', cx).attr('x2', cx1).attr('y1', r.y - 12).attr('y2', r.y - 12).attr('stroke', C.forecast).attr('stroke-width', 2.5).attr('marker-end', 'url(#ot-arrow)');
        g.append('circle').attr('cx', cx1).attr('cy', r.y).attr('r', 7).attr('fill', C.forecast).attr('stroke', C.surface).attr('stroke-width', 2);
      }
      g.append('circle').attr('cx', cx).attr('cy', r.y).attr('r', 7).attr('fill', C.actual).attr('stroke', C.surface).attr('stroke-width', 2);
    }
    svg.append('defs').html(`<marker id="ot-arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="${C.forecast}"/></marker>`);
    el.replaceChildren(svg.node()!);
  }
  $effect(() => { s; units; draw(); });
  onMount(() => watchLayout(el, draw));
</script>

<Explorable title="Odds ratios multiply odds, not probabilities" caption="Gold is the starting client, violet is the same client after the change you pick. Faint curves show how evenly spaced probabilities (5%, 10%, …, 95%) spread out on the odds line (drawn on a log scale, so it lines up with log-odds): near 0% and 100% a small change in probability is a huge change in log-odds. A logit coefficient adds a <b>fixed amount to the log-odds</b> (same arrow length on the bottom line wherever you start) and so <b>multiplies the odds by a fixed factor</b>, but how much the <b>probability</b> moves depends on where you start. Coefficients are from the chapter's five-fact logit fitted on 2,882 training clients.">
  {#snippet controls()}
    <label class="sl">Starting probability <input type="range" min="1" max="99" step="0.1" bind:value={p0} aria-valuetext={`${p0} percent`} /> <b>{p0.toFixed(1)}%</b></label>
    <div class="seg" role="group" aria-label="Change to apply">
      {#each PRED as x}<button class:on={pk === x.k} aria-pressed={pk === x.k} onclick={() => (pk = x.k)}>{x.label}</button>{/each}
    </div>
    <label class="sl">Apply it <input type="range" min="0" max={maxUnits} step="1" bind:value={units} aria-valuetext={`${units} times`} /> <b>{units}×</b></label>
  {/snippet}
  {#snippet aside()}
    <div class="side" aria-live="polite">
      <div class="eyebrow">Coefficient reader</div>
      <p class="read">Coefficient <b>{beta.toFixed(3)}</b> on the log-odds scale, so odds ratio <b>e<sup>{beta.toFixed(3)}</sup> = {OR.toFixed(3)}</b>. In words: {pred.unit} <b>multiplies the odds of a yes by {OR.toFixed(2)}</b>{OR < 1 ? ` (a ${(100 * (1 - OR)).toFixed(0)}% cut)` : ` (${OR >= 2 ? `${OR.toFixed(1)} times the odds` : `+${(100 * (OR - 1)).toFixed(0)}%`})`}, holding the other four facts fixed.</p>
      <table class="tr">
        <thead><tr><th></th><th>Before</th><th>After</th></tr></thead>
        <tbody>
          <tr><td>Probability</td><td>{pct(s.p)}</td><td class="hi">{pct(s.p1)}</td></tr>
          <tr><td>Odds</td><td>{fmtOdds(s.o)}</td><td class="hi">{fmtOdds(s.o1)}</td></tr>
          <tr><td>Log-odds</td><td>{s.lo.toFixed(2)}</td><td class="hi">{s.lo1.toFixed(2)}</td></tr>
        </tbody>
      </table>
      <p class="delta">Change in probability: <b>{units === 0 ? '0.0' : `${s.p1 >= s.p ? '+' : '−'}${Math.abs(100 * (s.p1 - s.p)).toFixed(1)}`} percentage points</b>. Move the starting probability and apply the same change again: the odds ratio stays put, the percentage-point change does not.</p>
    </div>
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 300px; }
  .side { font-size: .84rem; display: grid; gap: .7rem; }
  .read { margin: 0; color: var(--text-2); line-height: 1.5; }
  .tr { font-size: .8rem; margin: 0; font-variant-numeric: tabular-nums; }
  .tr th, .tr td { padding: .3rem .4rem; }
  .tr td.hi { color: var(--accent-text); font-weight: 650; }
  .delta { margin: 0; color: var(--muted); font-size: .78rem; }
</style>
