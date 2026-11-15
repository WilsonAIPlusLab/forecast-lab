<script lang="ts">
  // Counts are different: the Poisson distribution vs real hourly bike rentals, and the variance/mean ratio by hour.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import data from './nldata.json';

  const H = data.hourly as { working: number[][]; off: number[][] };
  let hr = $state(4);
  let day = $state('working');
  let lamMult = $state(1);
  let elTop: HTMLDivElement, elBot: HTMLDivElement;

  const stats = (v: number[]) => { const m = v.reduce((s, x) => s + x, 0) / v.length; const s2 = v.reduce((s, x) => s + (x - m) ** 2, 0) / (v.length - 1); return { m, v: s2, r: s2 / m, n: v.length }; };
  const counts = $derived(H[day as 'working' | 'off'][hr]);
  const st = $derived(stats(counts));
  const lam = $derived(st.m * lamMult);
  const byHour = $derived(H[day as 'working' | 'off'].map((v, h) => ({ h, ...stats(v) })));

  // log pmf of the Poisson distribution
  const lgamma = (z: number): number => { // Lanczos
    const g = 7, c = [0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313, -176.61502916214059, 12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7];
    if (z < 0.5) return Math.log(Math.PI / Math.sin(Math.PI * z)) - lgamma(1 - z);
    z -= 1; let x = c[0]; for (let i = 1; i < g + 2; i++) x += c[i] / (z + i);
    const t = z + g + 0.5; return 0.5 * Math.log(2 * Math.PI) + (z + 0.5) * Math.log(t) - t + Math.log(x);
  };
  const dpois = (k: number, l: number) => Math.exp(k * Math.log(l) - l - lgamma(k + 1));

  function drawTop() {
    if (!elTop) return;
    const W = elTop.clientWidth, Ht = Math.max(240, Math.min(300, W * 0.4));
    const max = Math.max(...counts), w = Math.max(1, Math.ceil(Math.max(max, lam * 2) / 45));
    const nb = Math.ceil((Math.max(max, lam * 2) + 1) / w);
    const obs = Array.from({ length: nb }, (_, i) => ({ x0: i * w, x1: (i + 1) * w, share: 0, pois: 0 }));
    counts.forEach((c) => { obs[Math.min(nb - 1, Math.floor(c / w))].share += 1 / counts.length; });
    for (let k = 0; k < nb * w; k++) obs[Math.floor(k / w)].pois += dpois(k, lam);
    const ymax = Math.max(...obs.map((o) => Math.max(o.share, o.pois)));
    const chart = Plot.plot({
      width: W, height: Ht, marginLeft: 48, marginRight: 16, marginTop: 20, marginBottom: 38, style: plotStyle(),
      x: { label: `Bikes rented in the hour starting ${hr}:00${w > 1 ? ` (bins of ${w})` : ''}`, labelAnchor: 'center', labelArrow: 'none' },
      y: { grid: true, label: null, domain: [0, ymax * 1.12], tickFormat: (d: number) => `${Math.round(d * 100)}%` },
      marks: [
        Plot.rectY(obs, { x1: 'x0', x2: 'x1', y: 'share', fill: C.actual, fillOpacity: 0.55, insetLeft: 0.5, insetRight: 0.5, tip: true, title: (d: any) => `${d.x0}${w > 1 ? `–${d.x1 - 1}` : ''} bikes\nObserved: ${(100 * d.share).toFixed(1)}% of hours\nPoisson: ${(100 * d.pois).toFixed(1)}%` }),
        Plot.line(obs, { x: (d: any) => (d.x0 + d.x1) / 2, y: 'pois', stroke: C.forecast, strokeWidth: 2.5, curve: 'monotone-x' }),
        Plot.dot(obs, { x: (d: any) => (d.x0 + d.x1) / 2, y: 'pois', fill: C.forecast, r: 2.5 }),
        Plot.text([obs[Math.min(nb - 1, Math.floor(lam / w))]], { x: (d: any) => (d.x0 + d.x1) / 2, y: 'pois', text: () => `Poisson, λ = ${lam.toFixed(1)}`, dy: -12, dx: lam / w > nb / 2 ? -8 : 8, textAnchor: lam / w > nb / 2 ? 'end' : 'start', fill: C.forecast, fontWeight: 700, fontSize: 12, stroke: 'var(--surface)', strokeWidth: 3, paintOrder: 'stroke' }),
      ],
    });
    chart.setAttribute('aria-label', `Distribution of hourly rentals at ${hr}:00 compared with a Poisson distribution with mean ${lam.toFixed(1)}. Variance is ${st.r.toFixed(1)} times the mean.`);
    elTop.replaceChildren(chart);
  }

  function drawBot() {
    if (!elBot) return;
    const W = elBot.clientWidth;
    const chart = Plot.plot({
      width: W, height: 200, marginLeft: 48, marginRight: 16, marginTop: 18, marginBottom: 36, style: plotStyle(),
      x: { label: 'Hour of the day', labelAnchor: 'center', labelArrow: 'none', tickFormat: (d: number) => (d % 3 === 0 ? `${d}h` : '') , padding: 0.15 },
      y: { type: 'log', grid: true, label: null, domain: [0.8, Math.max(150, 1.3 * Math.max(...byHour.map((d) => d.r)))], ticks: [1, 3, 10, 30, 100], tickFormat: (d: number) => `${d}×` },
      marks: [
        Plot.barY(byHour, { x: 'h', y1: 1, y2: 'r', fill: (d: any) => (d.h === hr ? C.forecast : C.s[0]), fillOpacity: (d: any) => (d.h === hr ? 1 : 0.55), tip: true, title: (d: any) => `${d.h}:00\nmean ${d.m.toFixed(1)} bikes\nvariance ${d.v.toFixed(0)}\nvariance ÷ mean = ${d.r.toFixed(1)}` }),
        Plot.ruleY([1], { stroke: C.good, strokeWidth: 2 }),
        Plot.text([{ h: 23, r: 1 }], { x: 'h', y: 'r', text: () => 'Poisson: variance = mean', dy: -8, textAnchor: 'end', fill: C.good, fontSize: 12, fontWeight: 650, stroke: 'var(--surface)', strokeWidth: 3, paintOrder: 'stroke' }),
      ],
    });
    chart.setAttribute('aria-label', 'Variance divided by mean of hourly rentals for each hour of the day, on a log scale; every hour is above 1.');
    elBot.replaceChildren(chart);
  }
  $effect(() => { counts; lam; drawTop(); });
  $effect(() => { byHour; hr; drawBot(); });
  $effect(() => { hr; day; lamMult = 1; });
  onMount(() => { const a = watchLayout(elTop, drawTop), b = watchLayout(elBot, drawBot); return () => { a(); b(); }; });
  const zeroObs = $derived(counts.filter((c) => c === 0).length / counts.length);
</script>

<Explorable title="Counts are not bell curves: Poisson fits the night, not the rush hour" caption="Each gold bar is the share of real hours (Capital Bikeshare, Washington, D.C., 2011–12) with that many rentals. The violet curve is a Poisson distribution with mean λ, set to the hour's average; nudge it to see that no λ fixes a bad fit. Below: variance ÷ mean for every hour, on a log scale. A Poisson count sits on the green line; real rentals sit above it everywhere, by a factor of up to about 100 at rush hour. Data: UCI Bike Sharing (Fanaee-T &amp; Gama 2013), CC BY 4.0.">
  {#snippet controls()}
    <label class="sl">Hour <input type="range" min="0" max="23" step="1" bind:value={hr} aria-valuetext={`${hr} o'clock`} /> <b>{hr}:00</b></label>
    <div class="seg" role="group" aria-label="Day type">
      <button class:on={day === 'working'} aria-pressed={day === 'working'} onclick={() => (day = 'working')}>Working days</button>
      <button class:on={day === 'off'} aria-pressed={day === 'off'} onclick={() => (day = 'off')}>Weekends &amp; holidays</button>
    </div>
    <label class="sl">λ <input type="range" min="0.5" max="1.5" step="0.01" bind:value={lamMult} aria-valuetext={`lambda ${lam.toFixed(1)}`} /> <b>{lam.toFixed(1)}</b></label>
  {/snippet}
  {#snippet aside()}
    <div class="side" aria-live="polite">
      <div class="stat"><span class="stat-v">{st.m.toFixed(1)}</span><span class="stat-l">mean bikes per hour at {hr}:00</span></div>
      <div class="stat"><span class="stat-v">{st.v.toFixed(st.v < 100 ? 1 : 0)}</span><span class="stat-l">variance (Poisson would say {st.m.toFixed(1)})</span></div>
      <div class="stat"><span class="stat-v" class:hot={st.r > 3}>{st.r.toFixed(1)}×</span><span class="stat-l">variance ÷ mean</span></div>
      <p class="note">Hours with zero rentals: <b>{(100 * zeroObs).toFixed(1)}%</b> observed, <b>{(100 * dpois(0, lam)).toFixed(1)}%</b> under Poisson.</p>
      <p class="note">{st.r < 3 ? 'Close to Poisson: small counts with little hidden variation.' : 'Overdispersed: weather, events and two years of growth make some hours far busier than others, more than a single λ can describe.'}</p>
    </div>
  {/snippet}
  <p class="key"><span class="sw gold"></span>Gold bars: {st.n} real {day === 'working' ? 'working-day' : 'weekend/holiday'} hours at {hr}:00, 2011–12 <span class="sw violet"></span>Violet: Poisson with λ = {lam.toFixed(1)}</p>
  <div bind:this={elTop} class="chart"></div>
  <div bind:this={elBot} class="chart2"></div>
</Explorable>

<style>
  .chart { min-height: 240px; }
  .chart2 { min-height: 200px; margin-top: .5rem; border-top: 1px dashed var(--border); padding-top: .5rem; }
  .side { display: grid; gap: .75rem; font-size: .84rem; }
  .key { margin: 0 0 .2rem; font-size: .8rem; color: var(--text-2); display: flex; flex-wrap: wrap; align-items: center; gap: .35rem .5rem; }
  .sw { display: inline-block; width: .8rem; height: .8rem; border-radius: 2px; }
  .sw.gold { background: var(--c-actual); opacity: .7; } .sw.violet { background: var(--c-forecast); margin-left: .6rem; }
  .note { margin: 0; color: var(--muted); font-size: .78rem; }
  .hot { color: var(--warm) !important; }
</style>
