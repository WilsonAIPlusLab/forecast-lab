<script lang="ts">
  // Explorable: a forecast made in differences (monthly inflation) is turned back into levels (the price index)
  // by a running sum and an exp(). The half-life slider sets how fast inflation returns to its anchor.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, futureDates, ym, type Pt } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';

  const H = 24;                                          // months forecast
  const HL = [1, 3, 6, 12, 18, 24, 36, 60, Infinity];   // half-life choices, months
  let hi = $state(4);                                    // index into HL (18 months = the ARMA(1,1) estimate)
  let anchor = $state(2.0);                              // long-run inflation, % per year
  let right: 'index' | 'yoy' = $state('index');
  let px: Pt[] = $state([]);
  let dEl: HTMLDivElement, lEl: HTMLDivElement;

  onMount(() => { loadSeries('PCEPILFE', { start: '2000-01-01' }).then((d) => (px = d.data)); });

  const hl = $derived(HL[hi]);
  const phi = $derived(Number.isFinite(hl) ? Math.pow(0.5, 1 / hl) : 1);
  const lp = $derived(px.map((p) => Math.log(p.value)));
  const n = $derived(lp.length);
  // starting point: the latest 12-month log change, in % per year
  const pi0 = $derived(n > 13 ? 100 * (lp[n - 1] - lp[n - 13]) : 0);
  const fut = $derived(n ? futureDates(px[n - 1].date, H, 12) : []);
  // forecast in differences: annualized monthly inflation, closing the gap to the anchor at rate phi
  const piF = $derived(Array.from({ length: H }, (_, i) => anchor + (pi0 - anchor) * phi ** (i + 1)));
  // back to levels: monthly log change = pi/1200; running sum; exp
  const cum = $derived(piF.reduce((a: number[], v) => (a.push((a.at(-1) ?? 0) + v / 1200), a), []));
  const lvl = $derived(cum.map((c) => (n ? px[n - 1].value * Math.exp(c) : 0)));
  const allLp = $derived([...lp, ...cum.map((c) => lp[n - 1] + c)]);
  const yoyAt = (k: number) => 100 * (Math.exp(allLp[k] - allLp[k - 12]) - 1);
  const yoy12 = $derived(n ? yoyAt(n - 1 + 12) : 0);
  const yoyNow = $derived(n ? yoyAt(n - 1) : 0);
  // the unit-root reference: inflation stays at pi0 forever
  const lvlRW = $derived(Array.from({ length: H }, (_, i) => (n ? px[n - 1].value * Math.exp((pi0 * (i + 1)) / 1200) : 0)));

  const FROM = new Date('2019-01-01T00:00:00');
  const FROM_L = new Date('2022-01-01T00:00:00');      // levels chart starts later so the two paths can be told apart
  function drawD() {
    if (!dEl || n < 14 || dEl.clientWidth < 120) return;
    const hist = px.slice(1).map((p, i) => ({ date: p.date, v: 1200 * (lp[i + 1] - lp[i]) })).filter((r) => r.date >= FROM);
    const fc = [{ date: px[n - 1].date, v: pi0 }, ...piF.map((v, i) => ({ date: fut[i], v }))];
    const c = Plot.plot({
      width: dEl.clientWidth, height: 240, marginLeft: 40, marginRight: 14, marginTop: 12, marginBottom: 28,
      style: plotStyle(), x: { label: null }, y: { label: '% per year', grid: true, ticks: 5 },
      marks: [
        Plot.ruleY([anchor], { stroke: C.fitted, strokeDasharray: '4 4', strokeWidth: 1.5 }),
        Plot.lineY(hist, { x: 'date', y: 'v', stroke: C.history, strokeWidth: 1.25, strokeOpacity: 0.55 }),
        Plot.lineY(fc, { x: 'date', y: 'v', stroke: C.forecast, strokeWidth: 3 }),
        Plot.text([{ date: fut[H - 1], v: anchor }], { x: 'date', y: 'v', text: () => `anchor ${anchor.toFixed(1)}%`, dy: anchor > pi0 ? -9 : 11, textAnchor: 'end', fill: C.fitted, fontSize: 12 }),
        Plot.tip([...hist.map((r) => ({ ...r, k: 'actual' })), ...fc.slice(1).map((r) => ({ ...r, k: 'forecast' }))], Plot.pointerX({ x: 'date', y: 'v', title: (r: any) => `${ym(r.date)} (${r.k})\n${r.v.toFixed(2)}% per year (annualized m/m)` })),
      ],
    });
    c.setAttribute('aria-label', `Monthly core PCE inflation, annualized, since 2019, with a forecast that starts at ${pi0.toFixed(1)}% and returns to ${anchor.toFixed(1)}% with a half-life of ${Number.isFinite(hl) ? hl + ' months' : 'infinity'}`);
    dEl.replaceChildren(c);
  }
  function drawL() {
    if (!lEl || n < 14 || lEl.clientWidth < 120) return;
    const idx0 = px.findIndex((p) => p.date >= FROM_L);
    let hist: any[], fc: any[], rw: any[], ylab: string;
    if (right === 'index') {
      hist = px.slice(idx0).map((p) => ({ date: p.date, v: p.value }));
      fc = [{ date: px[n - 1].date, v: px[n - 1].value }, ...lvl.map((v, i) => ({ date: fut[i], v }))];
      rw = [{ date: px[n - 1].date, v: px[n - 1].value }, ...lvlRW.map((v, i) => ({ date: fut[i], v }))];
      ylab = 'index, 2017 = 100';
    } else {
      hist = px.slice(Math.max(idx0, 12)).map((p, j) => ({ date: p.date, v: yoyAt(Math.max(idx0, 12) + j) }));
      fc = [{ date: px[n - 1].date, v: yoyNow }, ...fut.map((d, i) => ({ date: d, v: yoyAt(n + i) }))];
      const rwLp = [...lp, ...lvlRW.map((v) => Math.log(v))];
      rw = [{ date: px[n - 1].date, v: yoyNow }, ...fut.map((d, i) => ({ date: d, v: 100 * (Math.exp(rwLp[n + i] - rwLp[n + i - 12]) - 1) }))];
      ylab = '% change from a year earlier';
    }
    const unit = right === 'index' ? '' : '%';
    const c = Plot.plot({
      width: lEl.clientWidth, height: 240, marginLeft: 44, marginRight: 14, marginTop: 26, marginBottom: 28,
      style: plotStyle(), x: { label: null }, y: { label: ylab, grid: true, ticks: 5 },
      marks: [
        Plot.lineY(hist, { x: 'date', y: 'v', stroke: C.history, strokeWidth: 2 }),
        ...(Number.isFinite(hl) ? [Plot.lineY(rw, { x: 'date', y: 'v', stroke: C.muted, strokeWidth: 1.5, strokeDasharray: '3 3' }),
          Plot.text([rw.at(-1)], { x: 'date', y: 'v', text: () => 'if inflation never returns', dy: -9, textAnchor: 'end', fill: C.muted, fontSize: 12 })] : []),
        Plot.lineY(fc, { x: 'date', y: 'v', stroke: C.forecast, strokeWidth: 3 }),
        Plot.tip([...hist.map((r) => ({ ...r, k: 'actual' })), ...fc.slice(1).map((r) => ({ ...r, k: 'forecast' }))], Plot.pointerX({ x: 'date', y: 'v', title: (r: any) => `${ym(r.date)} (${r.k})\n${r.v.toFixed(2)}${unit} ${right === 'index' ? '(index, 2017 = 100)' : 'year over year'}` })),
      ],
    });
    c.setAttribute('aria-label', right === 'index' ? `Core PCE price index since 2019 with its forecast, which reaches ${lvl[11]?.toFixed(1)} after 12 months` : `12-month core PCE inflation since 2019 with its forecast, ${yoy12.toFixed(1)}% after 12 months`);
    lEl.replaceChildren(c);
  }
  $effect(() => { piF; drawD(); });
  $effect(() => { lvl; right; drawL(); });
  onMount(() => { const a = watchLayout(dEl, drawD), b = watchLayout(lEl, drawL); return () => { a(); b(); }; });

  const rows = $derived(n ? [0, 1, 2, 11].map((i) => ({ m: ym(fut[i]), pi: piF[i], d: piF[i] / 12, c: 100 * cum[i], l: lvl[i] })) : []);
</script>

<Explorable title="From a forecast of changes to a forecast of levels" caption="Left: the forecast is made <b>in differences</b>, as monthly core PCE inflation (100 × the change in log prices, × 12 to put it in % per year). It starts at the latest 12-month rate and closes the gap to the anchor at the speed set by the half-life. Right: the same forecast <b>in levels</b>. Each month's log change is added to a running total, and exp() turns the total back into the price index. The dashed grey line is the unit-root view, where inflation never returns. The ARMA(1,1) in the fit lab estimates a half-life of about 18 months and a mean of about 2.2%.">
  {#snippet controls()}
    <label class="sl">Half-life
      <input type="range" min="0" max={HL.length - 1} step="1" bind:value={hi} aria-label="Half-life of an inflation shock, months" aria-valuetext={Number.isFinite(hl) ? `${hl} months` : 'infinite, a unit root'} />
      <b>{Number.isFinite(hl) ? `${hl} mo` : '∞'}</b>
    </label>
    <label class="sl">Anchor
      <input type="range" min="1.5" max="3.5" step="0.1" bind:value={anchor} aria-label="Long-run inflation anchor, percent per year" aria-valuetext={`${anchor.toFixed(1)} percent`} />
      <b>{anchor.toFixed(1)}%</b>
    </label>
    <div class="seg" role="group" aria-label="Right-hand chart">
      <button class:on={right === 'index'} aria-pressed={right === 'index'} onclick={() => (right = 'index')}>Price index</button>
      <button class:on={right === 'yoy'} aria-pressed={right === 'yoy'} onclick={() => (right = 'yoy')}>12-month inflation</button>
    </div>
  {/snippet}
  <div class="pair">
    <div><div class="nm">In differences: monthly inflation, % per year</div><div bind:this={dEl} class="c"></div></div>
    <div><div class="nm">In levels: {right === 'index' ? 'the core PCE price index' : '12-month inflation'}</div><div bind:this={lEl} class="c"></div></div>
  </div>
  {#if rows.length}
    <div class="out" aria-live="polite">
      <div class="stat"><span class="stat-v">{lvl[11].toFixed(1)}</span><span class="stat-l">index in {rows[3].m} (now {px[n - 1].value.toFixed(1)})</span></div>
      <div class="stat"><span class="stat-v">{yoy12.toFixed(1)}%</span><span class="stat-l">12-month inflation in {rows[3].m} (now {yoyNow.toFixed(1)}%)</span></div>
      <div class="stat"><span class="stat-v">φ = {phi.toFixed(3)}</span><span class="stat-l">share of the gap that survives each month</span></div>
    </div>
    <div class="tw">
      <table class="recipe">
        <caption>The recipe, month by month: undo the difference (running sum), then undo the log: index = {px[n - 1].value.toFixed(2)} × exp(running total / 100).</caption>
        <thead><tr><th scope="col">Month</th><th scope="col" class="c2">Inflation, % per year</th><th scope="col">Log change, % (÷ 12)</th><th scope="col">Running total, %</th><th scope="col">Index</th></tr></thead>
        <tbody>
          {#each rows as r, i}
            {#if i === 3}<tr class="gap"><td colspan="5">…</td></tr>{/if}
            <tr><td>{r.m}</td><td class="c2">{r.pi.toFixed(2)}</td><td>{r.d.toFixed(3)}</td><td>{r.c.toFixed(3)}</td><td>{r.l.toFixed(2)}</td></tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</Explorable>

<style>
  .pair { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 1.2rem; }
  @media (max-width: 760px) { .pair { grid-template-columns: 1fr; } }
  .c { min-height: 240px; }
  .nm { font: 600 .86rem var(--font-ui); color: var(--text); margin-bottom: .3rem; }
  .out { display: flex; flex-wrap: wrap; gap: .8rem 2rem; margin: .8rem 0 .4rem; }
  .tw { overflow-x: auto; }
  .recipe { width: 100%; border-collapse: collapse; font-size: .82rem; font-variant-numeric: tabular-nums; margin: .4rem 0 0; }
  .recipe caption { text-align: left; color: var(--muted); font-size: .8rem; padding-bottom: .3rem; }
  .recipe th, .recipe td { padding: .3rem .5rem; border-bottom: 1px solid var(--border); text-align: right; }
  .recipe th:first-child, .recipe td:first-child { text-align: left; }
  .recipe th { color: var(--text-2); font-weight: 600; }
  .recipe tr.gap td { text-align: center; color: var(--muted); }
  @media (max-width: 520px) { .recipe { font-size: .76rem; } .recipe th, .recipe td { padding: .25rem .3rem; } .recipe .c2 { display: none; } }
</style>
