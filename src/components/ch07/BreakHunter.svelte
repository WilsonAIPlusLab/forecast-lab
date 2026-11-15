<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries } from '../../lib/ts';
  import { C, plotStyle, fmt, watchLayout } from '../../lib/viz/theme';
  import { ols, key, ymLabel } from './lib';
  import './viz';

  // Break hunter: slide a candidate break date, watch the Chow F-statistic, find the sup-F peak.
  // F follows strucchange::Fstats: (RSS_one_model - RSS_split) / (RSS_split / (n - 2k)), trimming 15% at each end.
  const OPTS = {
    annual: { label: 'Job growth, 1960–2019 (annual)', k: 1, crit: 8.61, unit: '% per year', start: 1980 },
    covid: { label: 'Claims → jobs link, 2010–2024 (monthly)', k: 2, crit: 11.56, unit: 'thousand jobs', start: 2015 },
  };
  type O = keyof typeof OPTS;
  let which: O = $state('annual');
  let data: { date: Date; y: number; x: number }[] = $state([]);
  let cand = $state(0);
  let el: HTMLDivElement, elF: HTMLDivElement;

  async function load() {
    const p = await loadSeries('PAYEMS');
    if (which === 'annual') {
      const byYear = new Map<number, number[]>();
      for (const q of p.data) (byYear.get(q.date.getFullYear()) || byYear.set(q.date.getFullYear(), []).get(q.date.getFullYear())!).push(q.value);
      const yrs = [...byYear].filter(([, v]) => v.length === 12).map(([yr, v]) => ({ yr, m: v.reduce((a, b) => a + b, 0) / 12 }));
      data = yrs.slice(1).map((r, i) => ({ date: new Date(r.yr, 0, 1), y: 100 * Math.log(r.m / yrs[i].m), x: 0 })).filter((r) => r.date.getFullYear() >= 1960 && r.date.getFullYear() <= 2019);
    } else {
      const c = await loadSeries('ICSA', { to: 'month' });
      const cl = new Map(c.data.map((q, i) => [key(q.date), i ? 100 * Math.log(q.value / c.data[i - 1].value) : NaN]));
      data = p.data.slice(1).map((q, i) => ({ date: q.date, y: q.value - p.data[i].value, x: cl.get(key(q.date)) ?? NaN }))
        .filter((r) => Number.isFinite(r.x) && key(r.date) >= '2010-01' && key(r.date) <= '2024-12');
    }
    const lo = Math.floor(0.15 * data.length);
    const i0 = data.findIndex((r) => r.date.getFullYear() === OPTS[which].start);
    cand = Math.max(lo, i0);
  }

  const design = (rows: typeof data) => rows.map((r) => (OPTS[which].k === 1 ? [1] : [1, r.x]));
  const calc = $derived.by(() => {
    if (!data.length) return null;
    const n = data.length, k = OPTS[which].k, lo = Math.floor(0.15 * n), hi = n - lo;
    const X = design(data), Y = data.map((r) => r.y);
    const full = ols(X, Y).rss;
    const curve: { i: number; date: Date; F: number }[] = [];
    for (let i = lo; i <= hi; i++) {
      const a = ols(X.slice(0, i), Y.slice(0, i)).rss, b = ols(X.slice(i), Y.slice(i)).rss;
      curve.push({ i, date: data[i - 1].date, F: (full - a - b) / ((a + b) / (n - 2 * k)) });
    }
    const peak = curve.reduce((m, c) => (c.F > m.F ? c : m));
    return { curve, peak, lo, hi };
  });
  const at = $derived(calc?.curve.find((c) => c.i === cand) ?? null);

  function draw() {
    if (!el || !calc || !at) return;
    const o = OPTS[which], W = el.clientWidth;
    const accent = getComputedStyle(el).getPropertyValue('--ch').trim() || C.s[3];
    const X = design(data), Y = data.map((r) => r.y);
    const fa = ols(X.slice(0, cand), Y.slice(0, cand)).beta, fb = ols(X.slice(cand), Y.slice(cand)).beta;
    const fitted = data.map((r, i) => ({ date: r.date, f: (i < cand ? fa : fb).reduce((s, b, j) => s + b * X[i][j], 0), seg: i < cand ? 'before' : 'after' }));
    const clip = which === 'covid' ? [-1500, 1500] : undefined;
    const off = which === 'covid' ? data.filter((r) => r.y < -1500 || r.y > 1500) : [];
    const breakDate = data[cand - 1].date;
    el.replaceChildren(Plot.plot({
      width: W, height: 250, marginLeft: 52, marginRight: 14, marginTop: 18, style: plotStyle(),
      x: { label: null }, y: { grid: true, label: o.unit, domain: clip, tickFormat: fmt }, clip: !!clip,
      marks: [
        Plot.ruleY([0], { stroke: C.borderStrong }),
        which === 'annual'
          ? Plot.ruleX(data, { x: 'date', y1: 0, y2: 'y', stroke: C.history, strokeWidth: 3, strokeOpacity: 0.55 })
          : Plot.lineY(data, { x: 'date', y: 'y', stroke: C.history, strokeWidth: 1.25, strokeOpacity: 0.6 }),
        Plot.lineY(fitted, { x: 'date', y: 'f', z: 'seg', stroke: (d: any) => (d.seg === 'before' ? C.s[0] : accent), strokeWidth: 3, curve: 'step-after' as any }),
        Plot.ruleX([breakDate], { stroke: C.text, strokeDasharray: '4 4', strokeWidth: 1.5 }),
        Plot.text([breakDate], { x: (d: Date) => d, frameAnchor: 'top', dy: -12, text: () => `candidate break: ${which === 'annual' ? breakDate.getFullYear() : ymLabel(breakDate)}`, fill: C.text, fontSize: 12, fontWeight: 650 }),
        ...off.map((r) => Plot.text([r], { x: 'date', frameAnchor: 'bottom', dy: -4, text: () => `${ymLabel(r.date)}: ${fmt(r.y)} (off the chart)`, fill: C.danger, fontSize: 12, textAnchor: 'start', dx: 4 })),
        Plot.tip(data, Plot.pointerX({ x: 'date', y: 'y', title: (r: any) => `${which === 'annual' ? r.date.getFullYear() : ymLabel(r.date)}: ${fmt(r.y)} ${o.unit}${which === 'covid' ? `\nclaims growth: ${r.x.toFixed(1)}%` : ''}` })),
      ],
    }));
    elF.replaceChildren(Plot.plot({
      width: W, height: 190, marginLeft: 52, marginRight: 14, style: plotStyle(),
      x: { label: null, domain: [data[0].date, data[data.length - 1].date] }, y: { grid: true, label: 'Chow F-statistic', type: which === 'covid' ? 'symlog' : 'linear', tickFormat: fmt },
      marks: [
        Plot.ruleY([o.crit], { stroke: C.danger, strokeDasharray: '4 4', strokeWidth: 2 }),
        Plot.text([o.crit], { y: (d: number) => d, frameAnchor: 'left', dx: 4, dy: -8, text: () => `5% critical value (sup-F): ${o.crit}`, fill: C.danger, fontSize: 12, textAnchor: 'start' }),
        Plot.lineY(calc.curve, { x: 'date', y: 'F', stroke: accent, strokeWidth: 2.2 }),
        Plot.dot([calc.peak], { x: 'date', y: 'F', stroke: C.text, r: 5, fill: 'none', strokeWidth: 1.5 }),
        Plot.dot([at], { x: 'date', y: 'F', fill: accent, r: 5.5 }),
        Plot.tip(calc.curve, Plot.pointerX({ x: 'date', y: 'F', title: (c: any) => `break after ${which === 'annual' ? c.date.getFullYear() : ymLabel(c.date)}\nF = ${c.F.toFixed(1)}` })),
      ],
    }));
  }

  $effect(() => { which; load(); });
  $effect(() => { calc; cand; draw(); });
  onMount(() => watchLayout(el, draw));

  const lbl = (d: Date) => (which === 'annual' ? String(d.getFullYear()) : ymLabel(d));
</script>

<Explorable title="Hunt for the break: where does one model stop fitting?" caption="Drag the candidate break date. The top chart fits one model before the date (blue) and another after it (orange); the bottom chart shows the Chow F-statistic for every candidate. The first and last 15% of dates are not tested, since one side would be too short. The <b>highest</b> F (circled) is the sup-F estimate of the break, and it counts only if it clears the dashed sup-F critical value, which is higher than an ordinary F critical value because you tried many dates. The claims option uses a log-like scale for F. Data: FRED (PAYEMS, ICSA), seasonally adjusted.">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Data">
      {#each Object.entries(OPTS) as [kk, d]}<button class:on={which === kk} onclick={() => (which = kk as O)}>{d.label}</button>{/each}
    </div>
    {#if calc}
      <label class="sl">Candidate break <input type="range" min={calc.lo} max={calc.hi} step="1" bind:value={cand} aria-label="Candidate break date" aria-valuetext={at ? lbl(at.date) : ''} /> <b>{at ? lbl(at.date) : ''}</b></label>
      <button class="btn btn-ghost btn-sm" onclick={() => calc && (cand = calc.peak.i)}>Jump to the peak</button>
    {/if}
  {/snippet}
  {#snippet aside()}
    {#if calc && at}
      <div class="ro" aria-live="polite">
        <div class="stat"><span class="stat-v" class:hot={at.F > OPTS[which].crit}>{at.F.toFixed(1)}</span><span class="stat-l">F at a break after {lbl(at.date)}</span></div>
        <div class="stat"><span class="stat-v">{calc.peak.F.toFixed(1)}</span><span class="stat-l">sup-F, at {lbl(calc.peak.date)}</span></div>
        <p class="v">
          {#if which === 'annual'}
            The peak clears the bar: average job growth was about <b>2.2%</b> a year through 2000 and about <b>0.7%</b> after. Slide to 2008: the Great Recession is a deep dip, but not a lasting change in the average.
          {:else}
            The F-statistic is ordinary everywhere except <b>one month</b>. That is the signature of an extreme <b>outlier</b> (March 2020, when the monthly average of claims rose about elevenfold), not of a new long-lasting relationship.
          {/if}
        </p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} role="img" aria-label="The data with separate fitted models before and after the candidate break"></div>
  <div bind:this={elF} role="img" aria-label="Chow F-statistic for every candidate break date"></div>
</Explorable>

<style>
  .ro { display: flex; flex-direction: column; gap: .8rem; font-size: .84rem; }
  .hot { color: var(--danger) !important; }
  .v { margin: 0; color: var(--text-2); }
</style>
