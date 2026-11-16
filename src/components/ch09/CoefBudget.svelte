<script lang="ts">
  // Coefficient budget: how fast a VAR uses up its data as you add variables, lags, or switch to monthly data.
  // Pure arithmetic on the chapter's sample (1960–2000): each equation has k*p + 1 coefficients,
  // estimated from T - p observations.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';

  const YEARS = 41; // 1960–2000
  const NAMES = ['Inflation', 'Unemployment', 'Funds rate', 'Term spread', 'Commodity prices', 'Output growth', 'Wages'];
  let k = $state(3);
  let freq: 'q' | 'm' = $state('q');
  let yrs = $state(1); // how far back the lags reach, in years
  let el: HTMLDivElement, elBar: HTMLDivElement;

  const per = (fq: 'q' | 'm') => (fq === 'q' ? 4 : 12);
  const stats = (kk: number, fq: 'q' | 'm', y: number) => {
    const T = YEARS * per(fq), p = Math.round(y * per(fq)), n = T - p, c = kk * p + 1;
    return { T, p, n, c, total: kk * c, ratio: n / c };
  };
  const s = $derived(stats(k, freq, yrs));
  const verdict = $derived(s.ratio >= 10 ? 'Comfortable' : s.ratio >= 5 ? 'Getting thin' : 'Very thin: expect noisy coefficients and wide bands');
  const lagWord = $derived(freq === 'q' ? `${s.p} quarterly lag${s.p > 1 ? 's' : ''}` : `${s.p} monthly lag${s.p > 1 ? 's' : ''}`);

  function draw() {
    if (!el) return;
    const W = el.clientWidth;
    const reach = [0.5, 1, 2];
    const rows = reach.flatMap((y) => [2, 3, 4, 5, 6, 7].map((kk) => ({ kk, y, r: stats(kk, freq, y).ratio })));
    const colr = (y: number) => C.s[y === 0.5 ? 0 : y === 1 ? 2 : 1];
    const lab = (y: number) => (y === 0.5 ? 'lags reach 6 months' : y === 1 ? 'lags reach 1 year' : 'lags reach 2 years');
    el.replaceChildren(Plot.plot({
      width: W, height: 260, marginLeft: 46, marginRight: W < 520 ? 16 : 140, marginBottom: 38, style: plotStyle(),
      x: { domain: [2, 7], ticks: [2, 3, 4, 5, 6, 7], tickFormat: (v: number) => `${v}`, label: 'variables in the VAR', labelAnchor: 'right' },
      y: { type: 'log', domain: [1, 100], ticks: [1, 2, 5, 10, 20, 50, 100], grid: true, label: 'observations per coefficient (log scale)', tickFormat: (v: number) => `${v}` },
      ariaLabel: `Observations per coefficient for ${freq === 'q' ? 'quarterly' : 'monthly'} data as the number of variables grows from 2 to 7, for lags reaching back 6 months, 1 year and 2 years`,
      marks: [
        Plot.rectY([{}], { x1: 2, x2: 7, y1: 1, y2: 5, fill: C.s[3], fillOpacity: 0.1 }),
        Plot.text([{}], { x: 2, y: 1.25, text: () => 'fewer than 5 per coefficient', textAnchor: 'start', dx: 6, fill: C.muted, fontSize: 12 }),
        Plot.lineY(rows, { x: 'kk', y: 'r', z: 'y', stroke: (d: any) => colr(d.y), strokeWidth: (d: any) => (d.y === yrs ? 3 : 1.5), strokeOpacity: (d: any) => (d.y === yrs ? 1 : 0.55) }),
        Plot.dot(rows, { x: 'kk', y: 'r', fill: (d: any) => colr(d.y), r: 2.5 }),
        W < 520 ? null : Plot.text(reach, { x: 7, y: (y: number) => stats(7, freq, y).ratio, text: (y: number) => lab(y), dx: 8, textAnchor: 'start', fill: (y: number) => colr(y), fontWeight: 650, fontSize: 12 }),
        Plot.dot([s], { x: () => k, y: 'ratio', r: 7, fill: 'none', stroke: C.text, strokeWidth: 2 }),
        Plot.tip(rows, Plot.pointer({ x: 'kk', y: 'r', title: (d: any) => `${d.kk} variables, ${lab(d.y)} (${stats(d.kk, freq, d.y).p} ${freq === 'q' ? 'quarterly' : 'monthly'} lags)
${d.r.toFixed(1)} observations per coefficient` })),
      ],
    }));
  }
  // one equation as a bar: the full bar is the observations; coloured blocks are coefficients
  function drawBar() {
    if (!elBar) return;
    const W = elBar.clientWidth;
    const blocks = [...Array.from({ length: k }, (_, i) => ({ v: NAMES[i], n: s.p, i })), { v: 'Constant', n: 1, i: -1 }];
    let x = 0;
    const segs = blocks.map((b) => { const r = { ...b, x1: x, x2: x + b.n }; x += b.n; return r; });
    elBar.replaceChildren(Plot.plot({
      width: W, height: 70, marginLeft: 8, marginRight: 8, marginTop: 4, marginBottom: 24, style: plotStyle(),
      x: { domain: [0, s.n], label: null, ticks: 4 },
      y: { axis: null, domain: [0, 1] },
      ariaLabel: `One equation uses ${s.c} coefficients out of ${s.n} observations`,
      marks: [
        Plot.rect([{}], { x1: 0, x2: s.n, y1: 0.15, y2: 0.85, fill: C.border, fillOpacity: 0.6 }),
        Plot.rect(segs, { x1: 'x1', x2: 'x2', y1: 0.15, y2: 0.85, fill: (d: any) => (d.i < 0 ? C.muted : C.s[d.i % 6]), stroke: C.surface, strokeWidth: 0.75, title: (d: any) => `${d.v}: ${d.n} coefficient${d.n > 1 ? 's' : ''}` }),
      ],
    }));
  }
  $effect(() => { s; k; yrs; freq; draw(); drawBar(); });
  onMount(() => { const a = watchLayout(el, draw); const b = watchLayout(elBar, drawBar); return () => { a(); b(); }; });
</script>

<Explorable title="How fast a VAR eats its data: count the coefficients before you add a variable"
  caption={`Choose how many variables go in, quarterly or monthly data, and how far back the lags reach. Every equation gets one coefficient per variable per lag, plus a constant, and all of them come out of the same 41 years of data (1960–2000). Lines: observations per coefficient as you add variables, for three lag reaches (your choice is the bold line); the shaded strip marks fewer than 5 per coefficient. Switch to monthly: the lines barely move. The ratios are simple arithmetic; the 5-and-10 cut-offs are a rough rule of thumb, not a law.`}>
  {#snippet controls()}
    <label class="sl">Variables <input type="range" min="2" max="7" bind:value={k} aria-valuetext={`${k} variables`} /> <b>{k}</b></label>
    <div class="seg" role="group" aria-label="Data frequency">
      <button class:on={freq === 'q'} onclick={() => (freq = 'q')}>Quarterly</button><button class:on={freq === 'm'} onclick={() => (freq = 'm')}>Monthly</button>
    </div>
    <div class="seg" role="group" aria-label="How far back the lags reach">
      {#each [0.5, 1, 2] as y}<button class:on={yrs === y} onclick={() => (yrs = y)}>{y === 0.5 ? '6 months' : y === 1 ? '1 year' : '2 years'}</button>{/each}
    </div>
  {/snippet}
  {#snippet aside()}
    <div class="ro" aria-live="polite">
      <div class="lbl">{k} variables, {lagWord}</div>
      <div class="big"><b>{s.total.toLocaleString()}</b> coefficients in the system</div>
      <dl>
        <dt>Per equation</dt><dd><b>{k} × {s.p} + 1 = {s.c}</b></dd>
        <dt>Observations per equation</dt><dd><b>{s.n}</b></dd>
        <dt>Observations per coefficient</dt><dd><b>{s.ratio.toFixed(1)}</b></dd>
      </dl>
      <p class="v" class:warn={s.ratio < 5}>{verdict}.</p>
      <p class="sum">{freq === 'm' ? 'Monthly data triple the observations, but reaching back the same number of years takes three times as many lags, so the ratio barely improves.' : 'The chapter’s VAR: 3 variables and one year of quarterly lags gives 13 coefficients per equation, about 12 observations each.'}</p>
    </div>
  {/snippet}
  <p class="cap">One equation: <b>{s.c} coefficients</b> (coloured, one block per variable's lags plus the constant) out of <b>{s.n} observations</b> (the whole bar)</p>
  <div bind:this={elBar} class="bar"></div>
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 250px; }
  .bar { min-height: 70px; margin-bottom: .6rem; }
  .cap { font-size: .8rem; color: var(--text-2); margin: 0 0 .2rem; }
  .ro { font-size: .82rem; }
  .lbl { font-size: .75rem; color: var(--muted); font-weight: 650; margin-bottom: .4rem; }
  .big { font-size: .95rem; color: var(--text-2); margin-bottom: .6rem; }
  .big b { font-size: 1.6rem; color: var(--text); font-variant-numeric: tabular-nums; margin-right: .2rem; }
  dl { display: grid; grid-template-columns: 1fr auto; gap: .3rem .7rem; margin: 0; font-variant-numeric: tabular-nums; }
  dt { color: var(--text-2); }
  dd { margin: 0; text-align: right; color: var(--text); }
  .v { margin: .7rem 0 0; font-weight: 650; color: var(--text); }
  .v.warn { color: var(--danger, #c2410c); }
  .sum { color: var(--text-2); margin: .5rem 0 0; line-height: 1.45; }
</style>
