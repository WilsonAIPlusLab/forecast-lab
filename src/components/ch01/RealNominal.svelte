<script lang="ts">
  // Real vs nominal, predict-first: the student guesses how much of the nominal growth in retail
  // sales since 2019 is real, then the CPI-deflated line is revealed.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { loadPublished, monthGrid, monthLabel, reducedMotion, avg, mkey } from './util';

  let nom: { date: Date; value: number }[] = $state([]);
  let real: { date: Date; value: number }[] = $state([]);
  let pGrowth = $state(0);
  let guess = $state(30);
  let revealed = $state(false);
  let el: HTMLDivElement;

  onMount(() => {
    Promise.all([loadSeries('RSAFS'), loadPublished('CPIAUCSL')]).then(([s, cg]) => {
      const cpi = new Map(cg.map((p) => [mkey(p.date), p.value]));
      const g = monthGrid(s);
      const r = g.map((p) => ({ date: p.date, value: p.value / (cpi.get(mkey(p.date)) ?? NaN) }));
      const base = (a: { date: Date; value: number }[]) => avg(a.filter((p) => p.date.getFullYear() === 2019).map((p) => p.value));
      const bn = base(g), br = base(r);
      nom = g.filter((p) => p.date.getFullYear() >= 2015).map((p) => ({ date: p.date, value: (100 * p.value) / bn }));
      const last = g[g.length - 1].date;
      pGrowth = 100 * ((cpi.get(mkey(last)) ?? NaN) / avg(cg.filter((p) => p.date.getFullYear() === 2019).map((p) => p.value)) - 1);
      real = r.filter((p) => p.date.getFullYear() >= 2015).map((p) => ({ date: p.date, value: (100 * p.value) / br }));
    });
    return watchLayout(el, () => draw(false));
  });

  const lastN = $derived(nom.length ? nom[nom.length - 1] : null);
  const lastR = $derived.by(() => { for (let i = real.length - 1; i >= 0; i--) if (Number.isFinite(real[i].value)) return real[i]; return null; });
  const gN = $derived(lastN ? lastN.value - 100 : 0);
  const gR = $derived(lastR ? lastR.value - 100 : 0);
  const gP = $derived(pGrowth);
  const share = $derived(gN ? (100 * gR) / gN : 0);

  function draw(animate = true) {
    if (!el || !nom.length || !lastN) return;
    const W = el.clientWidth;
    const x1 = lastN.date;
    const both = nom.map((p, i) => ({ date: p.date, n: p.value, r: real[i]?.value }));
    const marks: any[] = [
      Plot.ruleY([100], { stroke: C.text2, strokeWidth: 1.5, strokeOpacity: 0.7 }),
      Plot.text([0], { x: () => nom[0].date, y: 100, text: () => '2019 average = 100', dy: -8, textAnchor: 'start', fill: C.muted, fontSize: 12 }),
      Plot.lineY(nom, { x: 'date', y: 'value', stroke: C.history, strokeWidth: 2.4 }),
      Plot.text([lastN], { x: 'date', y: 'value', text: () => `Nominal +${gN.toFixed(1)}%`, dx: 8, textAnchor: 'start', fill: C.history, fontSize: 13, fontWeight: 650 }),
    ];
    if (!revealed) {
      marks.push(
        Plot.ruleY([100 + guess], { x1: () => new Date(x1.getFullYear() - 1, x1.getMonth(), 1), x2: () => x1, stroke: C.forecast, strokeWidth: 2.5, strokeDasharray: '4 4' }),
        Plot.text([0], { x: () => x1, y: 100 + guess, text: () => `Your guess: real +${guess}%`, dx: 8, textAnchor: 'start', fill: 'var(--accent-text)', fontSize: 13, fontWeight: 650 }),
      );
    } else {
      marks.push(
        Plot.areaY(both.filter((d) => Number.isFinite(d.r)), { x: 'date', y1: 'r', y2: 'n', fill: C.actual, fillOpacity: 0.13, className: 'rn-gap' }),
        Plot.lineY(real, { x: 'date', y: 'value', stroke: C.fitted, strokeWidth: 3, className: 'rn-real' }),
        Plot.text([lastR], { x: 'date', y: 'value', text: () => `Real +${gR.toFixed(1)}%`, dx: 8, textAnchor: 'start', fill: C.fitted, fontSize: 13, fontWeight: 650 }),
        Plot.ruleY([100 + guess], { x1: () => new Date(x1.getFullYear() - 1, x1.getMonth(), 1), x2: () => x1, stroke: C.forecast, strokeWidth: 2, strokeDasharray: '4 4', strokeOpacity: 0.7 }),
        Plot.text([0], { x: () => x1, y: 100 + guess, text: () => `guess +${guess}%`, dx: 8, dy: Math.abs(guess - gR) < 4 ? 14 : 0, textAnchor: 'start', fill: 'var(--accent-text)', fontSize: 12 }),
        Plot.text([0], { x: () => new Date(2023, 0, 1), y: () => 100 + (gN + gR) / 2 + 2, text: () => 'gap = inflation', fill: C.actual, fontSize: 13, fontWeight: 650, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
      );
    }
    marks.push(Plot.tip(both, Plot.pointerX({ x: 'date', y: 'n', title: (d: any) => `${monthLabel(d.date)}\nNominal: ${d.n.toFixed(1)}${revealed && Number.isFinite(d.r) ? `\nReal: ${d.r.toFixed(1)}` : ''}\n(index, 2019 average = 100)` })));
    const chart = Plot.plot({
      width: W, height: Math.max(300, Math.min(400, W * 0.48)), marginLeft: 48, marginRight: 128, marginTop: 14,
      style: plotStyle(), x: { label: null }, y: { grid: true, nice: true, label: null, domain: [75, Math.max(155, 100 + guess + 5)] },
      marks,
    });
    chart.setAttribute('role', 'img');
    chart.setAttribute('aria-label', revealed ? `Nominal retail sales up ${gN.toFixed(1)}% since 2019, real retail sales up ${gR.toFixed(1)}%.` : `Nominal retail sales up ${gN.toFixed(1)}% since 2019. Real line hidden until you guess.`);
    el.replaceChildren(chart);
    if (revealed && animate && !reducedMotion()) {
      const p = chart.querySelector('.rn-real path') as SVGPathElement | null;
      if (p) { const L = p.getTotalLength(); p.style.strokeDasharray = `${L}`; p.style.strokeDashoffset = `${L}`; p.getBoundingClientRect(); p.style.transition = 'stroke-dashoffset 900ms cubic-bezier(0.05,0.7,0.1,1)'; p.style.strokeDashoffset = '0'; }
      const a = chart.querySelector('.rn-gap') as SVGElement | null;
      if (a) { a.style.opacity = '0'; a.getBoundingClientRect(); a.style.transition = 'opacity 400ms 700ms'; a.style.opacity = '1'; }
    }
  }

  let wasRevealed = false;
  $effect(() => { nom; guess; const anim = revealed && !wasRevealed; wasRevealed = revealed; draw(anim); });
</script>

<Explorable title="Predict first: how much of the growth in retail sales is real?" caption={`Nominal U.S. retail and food services sales (RSAFS, $ millions, SA) are up about ${gN.toFixed(0)}% from their 2019 average. Drag the slider to guess how much of that is <b>real</b> growth, meaning more goods and meals rather than higher prices, then reveal the CPI-deflated line. Both lines are indexed to their 2019 average = 100. Data: FRED (RSAFS, CPIAUCSL).`}>
  {#snippet controls()}
    <label class="sl">Your guess: real growth since 2019
      <input type="range" min="0" max="50" step="1" bind:value={guess} disabled={revealed} aria-valuetext={`${guess} percent`} />
      <b>+{guess}%</b>
    </label>
    {#if !revealed}
      <button class="btn btn-sm" onclick={() => (revealed = true)}>Reveal the real line</button>
    {:else}
      <button class="btn btn-ghost btn-sm" onclick={() => (revealed = false)}>Guess again</button>
    {/if}
  {/snippet}
  {#snippet aside()}
    <div class="board" aria-live="polite">
      {#if revealed && lastR}
        <div class="stat"><span class="stat-v real">+{gR.toFixed(1)}%</span><span class="stat-l">real growth, 2019 average to {monthLabel(lastR.date)}</span></div>
        <div class="stat"><span class="stat-v">+{gP.toFixed(1)}%</span><span class="stat-l">rise in consumer prices (CPI) over the same span</span></div>
        <p class="verdict">You guessed <b>+{guess}%</b>, {Math.abs(guess - gR) <= 3 ? 'which is close. Well done.' : guess > gR ? `about ${Math.round(guess - gR)} points too high, a common mistake.` : `about ${Math.round(gR - guess)} points too low.`} Only about <b>{Math.round(share)}%</b> of the nominal increase is real; the rest is higher prices.</p>
        <p class="hint">Real growth is (1 + nominal) / (1 + inflation) − 1, not nominal minus inflation.</p>
      {:else}
        <div class="stat"><span class="stat-v">+{gN.toFixed(1)}%</span><span class="stat-l">nominal growth, 2019 average to {lastN ? monthLabel(lastN.date) : '…'}</span></div>
        <p class="verdict">Nominal means measured in current dollars. If prices rise, nominal sales rise even if people buy exactly the same things. How much of this is people buying <i>more</i>?</p>
      {/if}
    </div>
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 300px; }
  .board { font-size: .86rem; line-height: 1.55; display: grid; gap: .8rem; }
  .verdict { color: var(--text-2); margin: 0; }
  .hint { color: var(--muted); font-size: .78rem; margin: 0; }
  .real { color: var(--c-fitted); }
</style>
