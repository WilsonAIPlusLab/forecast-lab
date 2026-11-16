<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, rng } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { qnorm } from './models';

  // "Is 20 hits out of 24 good?" Audit the last N months of a simple one-month-ahead band
  // (the same audit as the coverage exercise), then compare the hit count with what an
  // honest band would produce by luck alone (exact binomial probabilities).
  const WINDOWS = [12, 24, 36];
  let level = $state(80);
  let N = $state(24);
  let y: { date: Date; value: number }[] = $state.raw([]);
  let fake: string[] | null = $state(null);    // one simulated honest audit ('inside' | 'above' | 'below'), for comparison
  let el: HTMLDivElement, el2: HTMLDivElement;
  let seed = 11;

  onMount(() => {
    loadSeries('RSAFS', { start: '2022-01-01' }).then((s) => (y = s.data));
    return watchLayout(el, draw);
  });

  // the audit: naive forecast (last month) ± z × sd of past month-to-month changes
  const audit = $derived.by(() => {
    if (!y.length) return null;
    const z = qnorm(1 - (1 - level / 100) / 2), n = y.length;
    const rows = [];
    for (let i = 0; i < N; i++) {
      const t = n - N + i, past = y.slice(0, t).map((p) => p.value);
      const d = past.slice(1).map((v, j) => v - past[j]);
      const m = d.reduce((a, b) => a + b, 0) / d.length;
      const s = Math.sqrt(d.reduce((a, b) => a + (b - m) ** 2, 0) / (d.length - 1));
      const lo = past[t - 1] - z * s, hi = past[t - 1] + z * s, a = y[t].value;
      rows.push({ date: y[t].date, side: a > hi ? 'above' : a < lo ? 'below' : 'inside', miss: ((a - past[t - 1]) / (z * s)) });
    }
    const hits = rows.filter((r) => r.side === 'inside').length;
    // exact probabilities of each hit count for an honest band: binomial(N, p)
    const p = level / 100;
    const lnC = (k: number) => { let s = 0; for (let j = 1; j <= k; j++) s += Math.log((N - k + j) / j); return s; };
    const probs = Array.from({ length: N + 1 }, (_, k) => ({ k, pr: Math.exp(lnC(k) + k * Math.log(p) + (N - k) * Math.log(1 - p)) }));
    // central range holding about 90% of honest audits
    let cum = 0, lo = 0, hi = N;
    for (const q of probs) { cum += q.pr; if (cum < 0.05) lo = q.k + 1; }
    cum = 0; for (let k = N; k >= 0; k--) { cum += probs[k].pr; if (cum < 0.05) hi = k - 1; }
    const inRange = probs.filter((q) => q.k >= lo && q.k <= hi).reduce((a, q) => a + q.pr, 0);
    return { rows, hits, probs, lo, hi, inRange, above: rows.filter((r) => r.side === 'above').length, below: rows.filter((r) => r.side === 'below').length };
  });
  // an honest band: each month is a hit with probability level/100; a miss is equally likely above or below
  function flip() { const r = rng(seed++); fake = Array.from({ length: N }, () => (r.u() < level / 100 ? 'inside' : r.u() < 0.5 ? 'above' : 'below')); }
  $effect(() => { level; N; fake = null; });

  function draw() {
    if (!el || !audit) return;
    const W = el.clientWidth;
    const cells = audit.rows.map((r, i) => ({ i, row: 'Real band', side: r.side, date: r.date }));
    if (fake) cells.push(...fake.map((side, i) => ({ i, row: 'Honest coin', side, date: audit.rows[i].date })));
    const col = (s: string) => (s === 'inside' ? C.good : C.danger);
    const mon = (d: Date) => d.toLocaleDateString('en-US', { month: 'short', year: '2-digit' });
    el.replaceChildren(Plot.plot({
      width: W, height: fake ? 128 : 84, marginLeft: 90, marginRight: 8, marginTop: 8, marginBottom: 26, style: plotStyle(),
      x: { label: null, domain: Array.from({ length: N }, (_, i) => i), tickFormat: (i: number) => (i % 6 === 0 ? mon(audit.rows[i].date) : ''), padding: 0.12 },
      y: { label: null, domain: ['Real band', 'Honest coin'].filter((r) => r === 'Real band' || fake), padding: 0.12 },
      marks: [
        Plot.cell(cells, { x: 'i', y: 'row', fill: (d: any) => col(d.side), fillOpacity: (d: any) => (d.side === 'inside' ? 0.5 : 0.9), rx: 3 }),
        // white triangles mark the side of each miss: pointing up = above the band, down = below
        Plot.dot(cells.filter((d) => d.side !== 'inside'), { x: 'i', y: 'row', symbol: 'triangle', r: 4.2, fill: '#fff', stroke: 'none', rotate: (d: any) => (d.side === 'above' ? 0 : 180) }),
        Plot.tip(cells.filter((d) => d.row === 'Real band'), Plot.pointer({ x: 'i', y: 'row', title: (d: any) => `${d.date.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}\n${d.side === 'inside' ? 'Inside the band (hit)' : d.side === 'above' ? 'Above the band (miss: sales higher)' : 'Below the band (miss: sales lower)'}` })),
      ],
    }));
    el2.replaceChildren(Plot.plot({
      width: W, height: 200, marginLeft: 46, marginRight: 12, marginTop: 22, marginBottom: 36, style: plotStyle(),
      x: { label: `Hits out of ${N} →`, domain: [Math.max(0, Math.floor(N * (level / 100) - 4 * Math.sqrt(N * 0.25))) - 0.5, N + 0.5] },
      y: { grid: true, label: '↑ Chance (%)', domain: [0, 118 * Math.max(...audit.probs.map((q) => q.pr))] },
      marks: [
        Plot.rectY(audit.probs, { x1: (d: any) => d.k - 0.42, x2: (d: any) => d.k + 0.42, y: (d: any) => 100 * d.pr, fill: (d: any) => (d.k >= audit.lo && d.k <= audit.hi ? C.forecast : C.muted), fillOpacity: (d: any) => (d.k >= audit.lo && d.k <= audit.hi ? 0.55 : 0.3) }),
        Plot.ruleX([audit.hits], { stroke: C.actual, strokeWidth: 3 }),
        Plot.text([audit.hits], { x: (d: any) => d, frameAnchor: 'top', dy: -12, text: () => `Real band: ${audit.hits}`, fill: C.text, fontSize: 12, fontWeight: 650, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
        Plot.tip(audit.probs, Plot.pointerX({ x: 'k', y: (d: any) => 100 * d.pr, title: (d: any) => `${d.k} hits out of ${N}\nAn honest ${level}% band gives this ${(100 * d.pr).toFixed(1)}% of the time` })),
      ],
    }));
  }
  $effect(() => { audit; fake; draw(); });
</script>

<Explorable title="Is 20 hits out of 24 good? Audit coverage on recent data, and allow for luck"
  caption="Each square is one recent month. The band is the simplest one-month-ahead 80% (or 95%) interval: last month's value ± z × the typical month-to-month change so far (the same audit as the exercise below). Green = the actual value landed inside; red ▲ = above the band, ▼ = below. The bars show how many hits an <b>honest</b> band, one that really catches the truth 80% (or 95%) of the time, would score by luck alone; violet bars mark the normal range of luck. Press <b>Flip an honest audit</b> to see what pure luck looks like. Data: U.S. retail and food services sales (RSAFS, SA, $ millions), January 2022 on.">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Interval level">
      {#each [80, 95] as l}<button class:on={level === l} aria-pressed={level === l} onclick={() => (level = l)}>{l}% band</button>{/each}
    </div>
    <div class="seg" role="group" aria-label="Audit window">
      {#each WINDOWS as w}<button class:on={N === w} aria-pressed={N === w} onclick={() => (N = w)}>Last {w} months</button>{/each}
    </div>
    <button class="btn btn-sm" onclick={flip}>Flip an honest audit</button>
  {/snippet}
  {#snippet aside()}
    {#if audit}
      <div class="ro" aria-live="polite">
        <div class="stat"><span class="stat-v">{audit.hits} of {N}</span><span class="stat-l">months inside the {level}% band ({(100 * audit.hits / N).toFixed(0)}%)</span></div>
        <p>An honest {level}% band scores between <b>{audit.lo}</b> and <b>{audit.hi}</b> hits in {(100 * audit.inRange).toFixed(0)}% of {N}-month audits.</p>
        <p class="verdict" class:bad={audit.hits < audit.lo || audit.hits > audit.hi}>
          {#if audit.hits < audit.lo}Verdict: too few hits to blame on luck. The band is too narrow.
          {:else if audit.hits > audit.hi}Verdict: more hits than luck explains. The band is probably too wide.
          {:else}Verdict: consistent with the promise. Do not over-react to a few misses.{/if}
        </p>
        <p>Misses: <b>{audit.above}</b> above, <b>{audit.below}</b> below. An honest band misses about equally often on each side; misses piling up on one side point to a biased forecast.</p>
        {#if fake}<p class="hint">Your honest coin scored {fake.filter((x) => x === 'inside').length} of {N}. Flip again: luck alone moves the count around.</p>{/if}
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} role="img" aria-label="Hit and miss record for the recent months, one square per month, with misses marked above or below"></div>
  <div bind:this={el2} role="img" aria-label="Probability of each hit count for an honest band, with the real band's hit count marked"></div>
</Explorable>

<style>
  .ro { font-size: .86rem; color: var(--text-2); display: grid; gap: .55rem; }
  .ro p { margin: 0; }
  .ro b { color: var(--text); font-variant-numeric: tabular-nums; }
  .verdict { border-left: 3px solid var(--good); padding-left: .6rem; color: var(--text); }
  .verdict.bad { border-left-color: var(--danger); }
  .hint { color: var(--muted); font-size: .8rem; }
</style>
