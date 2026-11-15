<script lang="ts">
  // Signature explorable 2: a predict-then-reveal game. Four mystery series; guess which ones return to a level.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { MYSTERY } from './spotData';

  type Guess = 'level' | 'wander' | null;
  let guesses: Guess[] = $state(MYSTERY.map(() => null));
  let revealed = $state(false);
  const els: HTMLDivElement[] = [];
  const letters = ['A', 'B', 'C', 'D'];

  const EXPLAIN: Record<string, string> = {
    rw: 'A random walk: each month adds a fresh shock to the last value, so it never feels pulled back. ADF cannot reject a unit root, and KPSS rejects stationarity. The tests agree.',
    unrate: 'The real U.S. unemployment rate, 2000 to 2019 (%, SA). Over these 20 years both tests say "unit root", and <code>ndiffs()</code> even asks for two differences, because the 2009 spike and slow decline dominate the window. Yet a rate stuck between 0% and 100% cannot wander forever. Over short windows, very persistent and nonstationary look the same. For forecasting a year ahead, treat it as having a unit root.',
    wn: 'White noise: independent shocks around zero. Both tests agree it is stationary, with no room for doubt.',
    ar: 'An AR(1) with φ = 0.9: stationary by construction. KPSS correctly finds no evidence against stationarity, but ADF <em>fails</em> to reject a unit root. That is ADF\'s low power: when φ is close to 1 and the sample is short, it often cannot tell the two apart.',
  };

  function drawAll() {
    MYSTERY.forEach((m, i) => {
      const el = els[i];
      if (!el) return;
      const d = m.y.map((v, t) => ({ t, v }));
      const mean = m.y.reduce((a, b) => a + b, 0) / m.y.length;
      const chart = Plot.plot({
        width: el.clientWidth, height: 150, marginLeft: 36, marginRight: 8, marginTop: 8, marginBottom: 22,
        style: plotStyle(), x: { label: null, ticks: [0, 60, 120, 180, 240], tickFormat: (t: number) => `year ${t / 12}` }, y: { label: null, grid: true, ticks: 4 },
        marks: [
          ...(revealed ? [Plot.ruleY([mean], { stroke: C.borderStrong, strokeDasharray: '4 4' })] : []),
          Plot.lineY(d, { x: 't', y: 'v', stroke: revealed ? (m.stationary ? C.fitted : C.actual) : C.history, strokeWidth: 1.6 }),
        ],
      });
      chart.setAttribute('aria-label', `Mystery series ${letters[i]}, 240 monthly observations`);
      el.replaceChildren(chart);
    });
  }

  const testVerdict = (m: (typeof MYSTERY)[number]) =>
    m.adfP < 0.05 && m.kpssP > 0.05 ? 'Both tests: stationary'
      : m.adfP >= 0.05 && m.kpssP <= 0.05 ? 'Both tests: unit root'
      : m.adfP >= 0.05 && m.kpssP > 0.05 ? 'Tests disagree (neither rejects)'
      : 'Tests disagree (both reject)';
  const correct = (m: (typeof MYSTERY)[number], g: Guess) =>
    m.stationary === null ? g !== null : (m.stationary ? g === 'level' : g === 'wander');
  const score = $derived(MYSTERY.filter((m, i) => correct(m, guesses[i])).length);
  const allGuessed = $derived(guesses.every((g) => g !== null));
  const p = (v: number, lo: boolean) => (lo && v <= 0.01 ? '≤ 0.01' : !lo && v >= 0.1 ? '≥ 0.10' : v.toFixed(2));

  $effect(() => { revealed; drawAll(); });
  onMount(() => {
    const offs = els.map((e) => watchLayout(e, drawAll));
    return () => offs.forEach((f) => f());
  });
</script>

<Explorable kicker="Game" title="Spot the random walk" caption="Three of these series were simulated in R and one is real U.S. data, in shuffled order. For each one, decide: does it keep returning to a fixed level, or does it wander? Then reveal what the ADF and KPSS tests say, and what each series really is. Each panel shows 240 months (20 years).">
  {#snippet controls()}
    <button class="btn btn-sm btn-primary" disabled={!allGuessed || revealed} onclick={() => (revealed = true)}>Reveal the tests</button>
    <button class="btn btn-sm btn-ghost" onclick={() => { guesses = MYSTERY.map(() => null); revealed = false; }}>Play again</button>
    {#if !allGuessed && !revealed}<span class="hint">Make all four calls to unlock the reveal.</span>{/if}
    {#if revealed}<span class="score" aria-live="polite">You matched {score} of 4.</span>{/if}
  {/snippet}
  <div class="grid">
    {#each MYSTERY as m, i}
      <div class="card" class:rev={revealed}>
        <div class="card-h">
          <span class="lt">Series {letters[i]}</span>
          <div class="seg" role="group" aria-label={`Your call for series ${letters[i]}`}>
            <button class:on={guesses[i] === 'level'} disabled={revealed} onclick={() => (guesses[i] = 'level')}>Returns to a level</button>
            <button class:on={guesses[i] === 'wander'} disabled={revealed} onclick={() => (guesses[i] = 'wander')}>Wanders</button>
          </div>
        </div>
        <div bind:this={els[i]} class="mini"></div>
        {#if revealed}
          <div class="reveal fade-up">
            <div class="truth"><b>{m.truth}</b>{#if correct(m, guesses[i])}<span class="ok">✓ your call holds up</span>{:else}<span class="no">✗ not this time</span>{/if}</div>
            <table>
              <thead><tr><th>ADF p<br /><small>H0: unit root</small></th><th>KPSS p<br /><small>H0: stationary</small></th><th><code>ndiffs()</code></th></tr></thead>
              <tbody><tr><td class:rej={m.adfP < 0.05}>{p(m.adfP, true)}</td><td class:rej={m.kpssP < 0.05}>{p(m.kpssP, false)}</td><td>{m.nd}</td></tr></tbody>
            </table>
            <div class="tv">{testVerdict(m)}</div>
            <p>{@html EXPLAIN[m.key]}</p>
          </div>
        {/if}
      </div>
    {/each}
  </div>
</Explorable>

<style>
  .grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1rem; }
  @media (max-width: 760px) { .grid { grid-template-columns: 1fr; } }
  .card { border: 1px solid var(--border); border-radius: 10px; padding: .7rem .8rem .6rem; background: var(--bg-2); }
  .card-h { display: flex; justify-content: space-between; align-items: center; gap: .5rem; flex-wrap: wrap; margin-bottom: .3rem; }
  .lt { font-weight: 700; color: var(--text); }
  .mini { min-height: 150px; }
  .hint { color: var(--muted); font-size: .8rem; }
  .score { font-weight: 700; color: var(--text); }
  .reveal { font-size: .82rem; color: var(--text-2); border-top: 1px solid var(--border); margin-top: .4rem; padding-top: .55rem; }
  .truth { display: flex; justify-content: space-between; gap: .5rem; flex-wrap: wrap; color: var(--text); }
  .ok { color: var(--good); font-weight: 650; }
  .no { color: var(--danger); font-weight: 650; }
  .reveal table { margin: .5rem 0 .3rem; font-size: .8rem; width: 100%; }
  .reveal th { font-weight: 600; text-align: left; }
  .reveal th small { font-weight: 400; color: var(--muted); }
  .reveal td { font-variant-numeric: tabular-nums; }
  .reveal td.rej { color: var(--text); font-weight: 700; }
  .tv { font-weight: 650; color: var(--accent-text); }
  .reveal p { margin: .35rem 0 0; line-height: 1.5; }
  .seg button:disabled { cursor: default; }
  @media (prefers-reduced-motion: reduce) { .fade-up { animation: none !important; } }
</style>
