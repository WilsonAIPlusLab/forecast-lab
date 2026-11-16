<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { ols, key } from './lib';
  import './viz';

  // Read an ADL(2,3) in words: impact vs cumulative effect, and a jump in claims that lasts
  // vs one that reverses next month. Model estimated by OLS on 1990–2019 in the browser.
  const P = 2, Q = 3, H = 24, SHOCK = 10;
  type Kind = 'stay' | 'blip';
  let kind: Kind = $state('stay');
  let h = $state(2);
  let fit: { irf: number[]; claims2019: number; jobsDec2019: number; avgGain: number } | null = $state(null);
  let el: HTMLDivElement;

  onMount(() => {
    (async () => {
      const [pay, cl] = await Promise.all([loadSeries('PAYEMS'), loadSeries('ICSA', { to: 'month' })]);
      const c = new Map(cl.data.map((d, i) => [key(d.date), i ? 100 * Math.log(d.value / cl.data[i - 1].value) : NaN]));
      const rows = pay.data.slice(1).map((d, i) => ({ k: key(d.date), dj: d.value - pay.data[i].value, dcl: c.get(key(d.date)) ?? NaN })).filter((r) => Number.isFinite(r.dcl));
      const X: number[][] = [], Y: number[] = [];
      for (let t = P; t < rows.length; t++) {
        if (rows[t].k < '1990-01' || rows[t].k > '2019-12') continue;
        const row = [1];
        for (let i = 1; i <= P; i++) row.push(rows[t - i].dj);
        for (let j = 0; j <= Q; j++) row.push(rows[t - j].dcl);
        X.push(row); Y.push(rows[t].dj);
      }
      const b = ols(X, Y).beta, phi = b.slice(1, 1 + P), beta = b.slice(1 + P);
      const irf: number[] = [];   // dynamic multipliers: response of jobs added to a one-time 1-point rise in claims growth
      for (let k = 0; k <= H; k++) { let v = k <= Q ? beta[k] : 0; for (let i = 1; i <= P; i++) if (k - i >= 0) v += phi[i - 1] * irf[k - i]; irf.push(v); }
      const c19 = cl.data.filter((d) => d.date.getFullYear() === 2019);
      const dec = pay.data.find((d) => key(d.date) === '2019-12');
      const gains = rows.filter((r) => r.k >= '1990-01' && r.k <= '2019-12').map((r) => r.dj);
      fit = { irf, claims2019: c19.reduce((a, d) => a + d.value, 0) / c19.length, jobsDec2019: dec ? dec.value : NaN, avgGain: gains.reduce((a, v) => a + v, 0) / gains.length };
    })();
    return watchLayout(el, draw);
  });

  // Claims growth path: 'stay' = +10 in month 0 only (level stays higher); 'blip' = +10 then −10 (level returns).
  const path = $derived.by(() => {
    if (!fit) return null;
    const m = fit.irf.map((v, k) => SHOCK * (kind === 'stay' ? v : v - (k ? fit!.irf[k - 1] : 0)));
    let s = 0;
    return m.map((v, k) => ({ k, v, cum: (s += v) }));
  });

  function draw() {
    if (!el || !path) return;
    const W = el.clientWidth;
    const accent = getComputedStyle(el).getPropertyValue('--ch').trim() || C.s[3];
    const at = path[h];
    const lab = { fontSize: 12, fontWeight: 650, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' } as any;
    const chart = Plot.plot({
      width: W, height: Math.max(270, Math.min(340, W * 0.5)), marginLeft: 54, marginRight: 16, marginTop: 22, marginBottom: 40, style: plotStyle(),
      x: { label: 'months after claims jump (0 = same month)', labelAnchor: 'center', labelArrow: 'none' as any, domain: [-0.7, H + 0.7] },
      y: { label: 'thousands of jobs', grid: true, labelAnchor: 'top' as any },
      marks: [
        Plot.ruleY([0], { stroke: C.borderStrong }),
        Plot.rectY(path, { x1: (d: any) => d.k - 0.38, x2: (d: any) => d.k + 0.38, y: 'v', fill: (d: any) => (d.k <= h ? C.s[0] : C.muted), fillOpacity: (d: any) => (d.k === h ? 1 : d.k < h ? 0.6 : 0.25) }),
        Plot.line(path, { x: 'k', y: 'cum', stroke: accent, strokeWidth: 2.4 }),
        Plot.ruleX([h], { stroke: C.text, strokeDasharray: '3 4', strokeOpacity: 0.6 }),
        Plot.dot([at], { x: 'k', y: 'cum', fill: accent, r: 5.5, stroke: C.surface, strokeWidth: 1.5 }),
        Plot.text([h < H - 9 ? path[H] : path[3]], { x: 'k', y: 'cum', text: () => 'running total', textAnchor: h < H - 9 ? 'end' : 'start', dx: h < H - 9 ? 0 : 8, dy: -10, fill: accent, ...lab }),
        Plot.text([at], { x: 'k', y: 'cum', text: (d: any) => `${fmtK(d.cum)}`, dx: 8, dy: 12, textAnchor: 'start', fill: C.text, ...lab }),
        Plot.tip(path, Plot.pointerX({ x: 'k', y: 'cum', title: (d: any) => `month ${d.k}\njobs added vs normal: ${fmtK(d.v)}\nrunning total: ${fmtK(d.cum)}` })),
      ],
    });
    chart.setAttribute('aria-label', `Jobs response to a ${SHOCK}% jump in claims; at month ${h} the running total is ${fmtK(at.cum)}`);
    el.replaceChildren(chart);
  }
  $effect(() => { path; h; draw(); });

  const fmtK = (x: number) => (x < 0 ? '−' : '+') + Math.abs(Math.round(x)).toLocaleString('en-US') + 'k';
  const words = (x: number) => Math.abs(x) < 0.5 ? `under 1,000 ${x < 0 ? 'fewer' : 'more'}` : `${Math.abs(Math.round(x)).toLocaleString('en-US')},000 ${x < 0 ? 'fewer' : 'more'}`;
  const mo = (k: number) => (k === 0 ? 'the same month' : k === 1 ? '1 month later' : `${k} months later`);
</script>

<Explorable title="Say it in words: impact, running total, and whether the jump lasts" caption={`The ADL(2,3) from this section, estimated on 1990–2019 in your browser. Bars: how many more or fewer jobs are added in each month than would have been without the jump in claims (the <b>dynamic multipliers</b>, times 10). Line: the running total of the bars, which is how far the <b>number of people employed</b> sits below where it would have been. Slide the month to read both numbers; switch the jump type to see why "does the jump last?" changes everything. Data: FRED (PAYEMS, ICSA), seasonally adjusted.`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Type of jump in claims">
      <button class:on={kind === 'stay'} aria-pressed={kind === 'stay'} onclick={() => (kind = 'stay')}>Claims jump 10% and stay up</button>
      <button class:on={kind === 'blip'} aria-pressed={kind === 'blip'} onclick={() => (kind = 'blip')}>One-month blip, then back</button>
    </div>
    <label class="sl">Month <input type="range" min="0" max={H} step="1" bind:value={h} aria-label="Months after the jump in claims" aria-valuetext={mo(h)} /> <b>{h}</b></label>
  {/snippet}
  {#snippet aside()}
    {#if fit && path}
      <div class="ro" aria-live="polite">
        <div class="stat"><span class="stat-v">{fmtK(path[h].v)}</span><span class="stat-l">jobs added in month {h}, vs normal</span></div>
        <div class="stat"><span class="stat-v">{fmtK(path[h].cum)}</span><span class="stat-l">running total, months 0–{h}: the level of employment</span></div>
        <p class="v">
          A 10% rise in claims is about <b>{Math.round(fit.claims2019 * 0.1 / 1000)},000 more new claims a week</b> at their 2019 average of {Math.round(fit.claims2019 / 1000)},000.
          {#if kind === 'stay'}
            If claims <b>stay</b> that high, {mo(h)} the economy adds about <b>{words(path[h].v)}</b> jobs than it otherwise would, and employment is about <b>{words(path[h].cum)}</b> jobs lower in total
            ({(Math.abs(path[h].cum) / fit.jobsDec2019 * 100).toFixed(2)}% of the {(fit.jobsDec2019 / 1000).toFixed(1)} million jobs in December 2019).
          {:else}
            If claims fall <b>back</b> the next month, the hit to job gains in month 0 is the same, but later months partly make it up: {mo(h)} employment is only about <b>{words(path[h].cum)}</b> jobs below where it would have been.
          {/if}
        </p>
        <p class="note">For scale: payrolls grew by about {Math.round(fit.avgGain)},000 jobs in an average month of 1990–2019.</p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart" role="img" aria-label="Bars of monthly job responses and a line of their running total"></div>
</Explorable>

<style>
  .chart { min-height: 270px; }
  .ro { display: flex; flex-direction: column; gap: .7rem; font-size: .84rem; }
  .v { margin: 0; color: var(--text-2); }
  .note { margin: 0; color: var(--muted); font-size: .78rem; }
</style>
