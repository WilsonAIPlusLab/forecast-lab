<script lang="ts">
  // Read a fan chart in plain words: pick a future month and a band, get the sentence an analyst would say.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { history, now, bn, bnShort, monthName } from './data';

  let k = $state(2);                       // index into the 24 forecast months (2 = the first December)
  let level = $state<80 | 95>(80);
  let el: HTMLDivElement;

  const H = now.mean.length;
  const hist = history.slice(-36);
  const last = history[history.length - 1];
  const lo = $derived(level === 80 ? now.lo80[k] : now.lo95[k]);
  const hi = $derived(level === 80 ? now.hi80[k] : now.hi95[k]);
  const pt = $derived(now.mean[k]);
  const width = $derived(hi - lo);
  const pctBelow = $derived((100 * (pt - lo)) / pt);
  const pctAbove = $derived((100 * (hi - pt)) / pt);
  const outside = $derived(level === 80 ? 2 : 1);
  const dots = $derived(level === 80 ? 10 : 20);
  // width of the same band one month ahead and 24 months ahead, for the "it widens" line
  const w1 = $derived(level === 80 ? now.hi80[0] - now.lo80[0] : now.hi95[0] - now.lo95[0]);
  const wH = $derived(level === 80 ? now.hi80[H - 1] - now.lo80[H - 1] : now.hi95[H - 1] - now.lo95[H - 1]);

  function draw() {
    if (!el) return;
    const W = el.clientWidth, narrow = W < 560;
    const rows = now.date.map((date, i) => ({ date, mean: now.mean[i], lo80: now.lo80[i], hi80: now.hi80[i], lo95: now.lo95[i], hi95: now.hi95[i] }));
    // join the fan to the last observed month so there is no gap
    const join = [{ date: last.date, mean: last.value, lo80: last.value, hi80: last.value, lo95: last.value, hi95: last.value }, ...rows];
    const sel = rows[k];
    const sLo = level === 80 ? sel.lo80 : sel.lo95, sHi = level === 80 ? sel.hi80 : sel.hi95;
    const chart = Plot.plot({
      width: W, height: Math.max(290, Math.min(400, W * 0.48)), marginLeft: 52, marginRight: narrow ? 12 : 70, marginTop: 18,
      style: plotStyle(), x: { label: null, ticks: narrow ? 4 : 7 },
      y: { grid: true, label: '$ billions', tickFormat: (v: number) => `${Math.round(v / 1000)}`, labelAnchor: 'top' },
      marks: [
        Plot.areaY(join, { x: 'date', y1: 'lo95', y2: 'hi95', fill: C.forecast, fillOpacity: level === 95 ? 0.26 : 0.13 }),
        Plot.areaY(join, { x: 'date', y1: 'lo80', y2: 'hi80', fill: C.forecast, fillOpacity: level === 80 ? 0.34 : 0.16 }),
        Plot.lineY(hist, { x: 'date', y: 'value', stroke: C.history, strokeWidth: 1.8 }),
        Plot.lineY(join, { x: 'date', y: 'mean', stroke: C.forecast, strokeWidth: 2.4 }),
        Plot.ruleX([last.date], { stroke: C.borderStrong, strokeDasharray: '3,4' }),
        Plot.text([last.date], { x: (d: any) => d, frameAnchor: 'top', dx: -6, dy: 2, textAnchor: 'end', text: () => 'Data', fill: C.muted, fontSize: 12, fontWeight: 700 }),
        Plot.text([last.date], { x: (d: any) => d, frameAnchor: 'top', dx: 6, dy: 2, textAnchor: 'start', text: () => 'Forecast', fill: C.muted, fontSize: 12, fontWeight: 700 }),
        // the selected month: the band as a bracket, the point as a dot
        Plot.ruleX([sel], { x: 'date', y1: sLo, y2: sHi, stroke: C.text, strokeWidth: 2.5 }),
        Plot.ruleY([sLo, sHi], { y: (v: number) => v, x1: new Date(+sel.date - 12 * 864e5), x2: new Date(+sel.date + 12 * 864e5), stroke: C.text, strokeWidth: 2.5 }),
        Plot.dot([sel], { x: 'date', y: 'mean', r: 5, fill: C.forecast, stroke: C.surface, strokeWidth: 2 }),
        ...(narrow ? [] : [
          Plot.text([sel], { x: 'date', y: () => sHi, dx: 10, textAnchor: 'start', text: () => bnShort(sHi), fill: C.text, fontSize: 12, fontWeight: 650, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
          Plot.text([sel], { x: 'date', y: () => sLo, dx: 10, textAnchor: 'start', text: () => bnShort(sLo), fill: C.text, fontSize: 12, fontWeight: 650, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
        ]),
        Plot.tip(rows, Plot.pointerX({ x: 'date', y: 'mean', title: (r: any) => `${monthName(r.date, false)}\nPoint forecast: ${bn(r.mean, 1)}\n80% band: ${bnShort(r.lo80)} to ${bnShort(r.hi80)}\n95% band: ${bnShort(r.lo95)} to ${bnShort(r.hi95)}` })),
      ],
    });
    el.replaceChildren(chart);
  }

  $effect(() => { k; level; draw(); });
  onMount(() => watchLayout(el, draw));
</script>

<Explorable title="Say the forecast out loud: one month, one band, one sentence" caption={`U.S. retail sales (RSXFSN, not seasonally adjusted), in $ billions per month. The fan is the forecast from the first lab: a seasonal ARIMA on log sales, fitted to data through ${monthName(history[history.length - 1].date)}. Drag the slider to pick a month (or use the arrow keys), switch between the 80% and 95% bands, and read the sentence on the right. Hover the chart for exact values.`}>
  {#snippet controls()}
    <label class="sl">Month <input type="range" min="0" max={H - 1} step="1" bind:value={k} aria-label="Forecast month" aria-valuetext={`${monthName(now.date[k])}, ${k + 1} months ahead`} /> <b class="mo">{monthName(now.date[k], false)}</b></label>
    <div class="seg" role="group" aria-label="Band to read">
      <button class:on={level === 80} aria-pressed={level === 80} onclick={() => (level = 80)}>80% band</button>
      <button class:on={level === 95} aria-pressed={level === 95} onclick={() => (level = 95)}>95% band</button>
    </div>
  {/snippet}
  {#snippet aside()}
    <div class="fr" aria-live="polite">
      <div class="eyebrow">In plain words</div>
      <p class="say">
        For <b>{monthName(now.date[k])}</b> ({k + 1} {k === 0 ? 'month' : 'months'} after the last data point), our best guess is
        <b class="c-fc">{bn(pt)}</b>. The model gives {level === 80 ? 'an' : 'a'} {level}% chance that the actual figure lands between <b>{bn(lo)}</b> and <b>{bn(hi)}</b>.
      </p>
      <div class="pict" aria-label={`Picture: out of ${dots} months like this, about ${dots - outside} land inside the band and ${outside} outside.`} role="img">
        {#each Array(dots) as _, i}<span class="pd" class:out={i >= dots - outside}></span>{/each}
      </div>
      <p class="small">Out of {dots} forecasts like this one, expect about <b>{outside}</b> {outside === 1 ? 'miss' : 'misses'} outside the band. A miss is not a broken model.</p>
      <dl class="nums">
        <dt>Band width</dt><dd>{bn(width)}</dd>
        <dt>Below / above the guess</dt><dd>−{pctBelow.toFixed(1)}% / +{pctAbove.toFixed(1)}%</dd>
        <dt>Width 1 vs 24 months out</dt><dd>{bnShort(w1)} → {bnShort(wH)}</dd>
      </dl>
    </div>
  {/snippet}
  <div bind:this={el} class="chart" role="img" aria-label={`Fan chart of U.S. retail sales. For ${monthName(now.date[k])} the point forecast is ${bn(pt)} and the ${level}% band runs from ${bn(lo)} to ${bn(hi)}.`}></div>
</Explorable>

<style>
  .chart { min-height: 290px; }
  .mo { min-width: 8ch !important; }
  .fr { display: grid; gap: .7rem; font-size: .88rem; color: var(--text-2); }
  .say { margin: 0; line-height: 1.55; color: var(--text); }
  .c-fc { color: var(--accent-text); }
  .pict { display: flex; flex-wrap: wrap; gap: 4px; max-width: 220px; }
  .pd { width: 14px; height: 14px; border-radius: 50%; background: var(--c-forecast); }
  .pd.out { background: transparent; border: 2px dashed var(--danger); width: 10px; height: 10px; }
  .small { margin: 0; font-size: .8rem; color: var(--muted); }
  .nums { display: grid; grid-template-columns: auto auto; gap: .25rem .8rem; margin: 0; font-size: .8rem; }
  .nums dt { color: var(--muted); }
  .nums dd { margin: 0; text-align: right; font-variant-numeric: tabular-nums; color: var(--text); font-weight: 600; }
</style>
