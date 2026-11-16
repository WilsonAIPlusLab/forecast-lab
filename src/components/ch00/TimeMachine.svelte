<script lang="ts">
  // Step back in time: make the chapter's forecast at the end of an earlier year, then check it against what happened.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { history, past, bnShort, monthName } from './data';

  let pick = $state(past.findIndex((p) => p.origin === 2018));
  let revealed = $state(false);
  let el: HTMLDivElement;

  const f = $derived(past[pick]);
  const score = (p: typeof past[number]) => {
    const in80 = p.actual.filter((a, i) => a >= p.lo80[i] && a <= p.hi80[i]).length;
    const in95 = p.actual.filter((a, i) => a >= p.lo95[i] && a <= p.hi95[i]).length;
    const miss = (100 * p.actual.reduce((s, a, i) => s + Math.abs(a - p.mean[i]) / a, 0)) / p.actual.length;
    const exact = p.actual.filter((a, i) => Math.abs(a - p.mean[i]) / a < 0.005).length;   // within 0.5%
    return { in80, in95, miss, exact };
  };
  const sc = $derived(score(f));
  const all = past.map((p) => ({ origin: p.origin, ...score(p) }));
  const normal = all.filter((r) => r.origin !== 2019);
  const tot80 = normal.reduce((s, r) => s + r.in80, 0), tot95 = normal.reduce((s, r) => s + r.in95, 0), n = normal.length * 24;

  function choose(i: number) { pick = i; revealed = false; }

  function draw() {
    if (!el) return;
    const W = el.clientWidth, narrow = W < 560;
    const o = new Date(f.origin, 11, 1);
    const hist = history.filter((p) => p.date <= o && p.date > new Date(f.origin - 3, 11, 1));
    const last = hist[hist.length - 1];
    const rows = f.date.map((date, i) => ({ date, mean: f.mean[i], lo80: f.lo80[i], hi80: f.hi80[i], lo95: f.lo95[i], hi95: f.hi95[i], a: f.actual[i] }));
    const join = [{ date: last.date, mean: last.value, lo80: last.value, hi80: last.value, lo95: last.value, hi95: last.value }, ...rows];
    const act = rows.map((r) => ({ ...r, inside: r.a >= r.lo80 && r.a <= r.hi80 ? 'in80' : r.a >= r.lo95 && r.a <= r.hi95 ? 'in95' : 'out' }));
    const allVals = [...hist.map((p) => p.value), ...rows.flatMap((r) => [r.lo95, r.hi95, r.a])];
    const chart = Plot.plot({
      width: W, height: Math.max(290, Math.min(400, W * 0.48)), marginLeft: 56, marginRight: 16, marginTop: 22,
      style: plotStyle(), x: { label: null, ticks: narrow ? 4 : 7 },
      // units live in the tick labels ($ billions per month), which leaves the top free for the "You stand here" label
      y: { grid: true, label: null, domain: [Math.min(...allVals) * 0.97, Math.max(...allVals) * 1.02], tickFormat: (v: number) => `$${Math.round(v / 1000)}B` },
      marks: [
        Plot.areaY(join, { x: 'date', y1: 'lo95', y2: 'hi95', fill: C.forecast, fillOpacity: 0.13 }),
        Plot.areaY(join, { x: 'date', y1: 'lo80', y2: 'hi80', fill: C.forecast, fillOpacity: 0.26 }),
        Plot.lineY(hist, { x: 'date', y: 'value', stroke: C.history, strokeWidth: 1.8 }),
        Plot.lineY(join, { x: 'date', y: 'mean', stroke: C.forecast, strokeWidth: 2.2 }),
        Plot.ruleX([o], { stroke: C.borderStrong, strokeDasharray: '3,4' }),
        Plot.text([o], { x: (d: any) => d, frameAnchor: 'top', dx: -6, dy: -14, textAnchor: 'end', text: () => (narrow ? 'You stand here' : `You stand here: ${monthName(o, false)}`), fill: C.muted, fontSize: 12, fontWeight: 700 }),
        ...(revealed ? [
          Plot.lineY([{ date: last.date, a: last.value }, ...act], { x: 'date', y: 'a', stroke: C.actual, strokeWidth: 2, strokeOpacity: 0.85 }),
          // inside the 80% band: filled dot; inside only the 95% band: hollow dot; outside both: a cross (shape, not just colour)
          Plot.dot(act.filter((r) => r.inside === 'in80'), { x: 'date', y: 'a', r: 3.5, fill: C.actual }),
          Plot.dot(act.filter((r) => r.inside === 'in95'), { x: 'date', y: 'a', r: 4, stroke: C.actual, strokeWidth: 2, fill: C.surface }),
          Plot.dot(act.filter((r) => r.inside === 'out'), { x: 'date', y: 'a', r: 5, symbol: 'times', stroke: C.danger, strokeWidth: 2.5 }),
          Plot.text(act, Plot.selectLast({ x: 'date', y: 'a', text: () => 'Actual', textAnchor: 'end', dy: -12, fill: C.actual, fontSize: 12, fontWeight: 700, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' })),
        ] : []),
        Plot.tip(rows, Plot.pointerX({ x: 'date', y: 'mean', title: (r: any) => `${monthName(r.date, false)}\nForecast: ${bnShort(r.mean)}\n80% band: ${bnShort(r.lo80)} to ${bnShort(r.hi80)}${revealed ? `\nActual: ${bnShort(r.a)} (${r.a >= r.mean ? '+' : ''}${((100 * (r.a - r.mean)) / r.mean).toFixed(1)}%)` : ''}` })),
      ],
    });
    el.replaceChildren(chart);
  }

  $effect(() => { pick; revealed; draw(); });
  onMount(() => watchLayout(el, draw));
</script>

<Explorable kicker="Time machine" title="Go back in time: did the band catch what really happened?" caption={`Each forecast uses the first lab's recipe (auto.arima on log retail sales, data from January 2012) but only the data available at the end of the chosen year, then looks 24 months ahead. Pick a year, guess how many of the 24 actual months land inside the bands, then reveal. Filled dot = inside the 80% band; hollow dot = inside the 95% band only; red cross = outside both. Actual values are today's revised data.`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Forecast made at the end of">
      {#each past as p, i}<button class:on={pick === i} aria-pressed={pick === i} onclick={() => choose(i)}>Dec {p.origin}</button>{/each}
    </div>
    <button class="btn btn-primary btn-sm" onclick={() => (revealed = !revealed)}>{revealed ? 'Hide what happened' : 'Reveal what happened'}</button>
  {/snippet}
  {#snippet aside()}
    <div class="tm" aria-live="polite">
      {#if !revealed}
        <div class="eyebrow">Before you reveal</div>
        <p>If the bands are honest, about <b>19 of 24</b> months (80%) should land inside the darker band, and about <b>23 of 24</b> (95%) inside the lighter one.</p>
        <p class="muted">How many months will the bold line hit almost exactly (within 0.5%)?</p>
      {:else}
        <div class="eyebrow">Forecast from Dec {f.origin}</div>
        <div class="stats">
          <div class="stat"><span class="stat-v">{sc.in80}<small>/24</small></span><span class="stat-l">inside the 80% band</span></div>
          <div class="stat"><span class="stat-v">{sc.in95}<small>/24</small></span><span class="stat-l">inside the 95% band</span></div>
        </div>
        <p>The bold line missed by <b>{sc.miss.toFixed(1)}%</b> a month on average and was within 0.5% in only <b>{sc.exact}</b> of 24 months. The point is rarely exactly right; the band is the message.</p>
        {#if f.origin === 2019}
          <p class="warn">COVID: no model fitted to 2012–2019 could expect April 2020's crash or the 2021 boom. Bands assume the future behaves like the past.</p>
        {:else}
          <p class="muted">Across the six non-COVID years: {tot80} of {n} months ({Math.round((100 * tot80) / n)}%) inside the 80% bands, {tot95} of {n} ({Math.round((100 * tot95) / n)}%) inside the 95% bands.</p>
        {/if}
      {/if}
    </div>
  {/snippet}
  <div bind:this={el} class="chart" role="img" aria-label={`Retail sales forecast made in December ${f.origin} for the next 24 months${revealed ? `, with the actual values: ${sc.in80} of 24 inside the 80% band and ${sc.in95} of 24 inside the 95% band` : ''}.`}></div>
</Explorable>

<style>
  .chart { min-height: 290px; }
  .tm { font-size: .86rem; color: var(--text-2); display: grid; gap: .6rem; }
  .tm p { margin: 0; line-height: 1.5; }
  .stats { display: flex; gap: 1.4rem; }
  .stat-v small { font-size: .8rem; color: var(--muted); font-weight: 500; }
  .muted { color: var(--muted); }
  .warn { color: var(--danger); }
</style>
