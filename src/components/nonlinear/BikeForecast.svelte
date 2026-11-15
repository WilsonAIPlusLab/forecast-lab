<script lang="ts">
  // Forecast tomorrow's rentals: Poisson vs negative-binomial prediction intervals on held-out days, with a coverage audit.
  import { onMount } from 'svelte';
  import Explorable from '../Explorable.svelte';
  import { css, watchLayout } from '../../lib/viz/theme';
  import { fanChart } from './viz'; // also registers the "nl-fan" chart type used by the code labs
  import data from './nldata.json';

  const B = data.bikes as any;
  let model = $state('pois');
  let level = $state('95');
  let el: HTMLDivElement;
  let cov = $state(0);

  const m = $derived(model === 'pois' ? { mu: B.mu_p, lo80: B.lo80.pois, hi80: B.hi80.pois, lo95: B.lo95.pois, hi95: B.hi95.pois } : { mu: B.mu_n, lo80: B.lo80.nb, hi80: B.hi80.nb, lo95: B.lo95.nb, hi95: B.hi95.nb });
  const width = $derived.by(() => { const lo = level === '80' ? m.lo80 : m.lo95, hi = level === '80' ? m.hi80 : m.hi95; const w = hi.map((h: number, i: number) => h - lo[i]).sort((a: number, b: number) => a - b); const h = w.length / 2; return w.length % 2 ? w[Math.floor(h)] : (w[h - 1] + w[h]) / 2; });
  const mae = (mu: number[]) => mu.reduce((s, v, i) => s + Math.abs(B.y[i] - v), 0) / mu.length;
  const maeP = mae(B.mu_p), maeN = mae(B.mu_n), maeNaive = mae(B.naive);

  function draw() {
    if (!el) return;
    const r = fanChart(el, { width: el.clientWidth, css, date: B.date, actual: B.y, mean: m.mu, lo80: m.lo80, hi80: m.hi80, lo95: m.lo95, hi95: m.hi95, hist_date: B.hist_date, hist: B.hist, level: level as '80' | '95' });
    cov = r.coverage;
    el.replaceChildren(r.node);
  }
  $effect(() => { model; level; draw(); });
  onMount(() => watchLayout(el, draw));
</script>

<Explorable title="Same forecast, very different honesty: Poisson vs negative binomial intervals" caption="Both models were fitted on January 2011 to August 2012 and forecast each day of September to December 2012 from its calendar and weather. Their point forecasts are almost identical; their intervals are not. Gold dots fell inside the interval, red crosses outside; the strip underneath scores every day. A Poisson interval assumes the variance equals the mean (about 5,800 here, so a standard deviation of about 76 bikes) when the real day-to-day noise is far larger. Data: UCI Bike Sharing (Fanaee-T &amp; Gama 2013), CC BY 4.0.">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Model">
      <button class:on={model === 'pois'} aria-pressed={model === 'pois'} onclick={() => (model = 'pois')}>Poisson</button>
      <button class:on={model === 'nb'} aria-pressed={model === 'nb'} onclick={() => (model = 'nb')}>Negative binomial</button>
    </div>
    <div class="seg" role="group" aria-label="Interval level">
      <button class:on={level === '80'} aria-pressed={level === '80'} onclick={() => (level = '80')}>80% interval</button>
      <button class:on={level === '95'} aria-pressed={level === '95'} onclick={() => (level = '95')}>95% interval</button>
    </div>
  {/snippet}
  {#snippet aside()}
    <div class="side" aria-live="polite">
      <div class="stat"><span class="stat-v" class:bad={cov < +level / 100 - 0.1}>{(100 * cov).toFixed(0)}%</span><span class="stat-l">of the 122 test days fell inside the {level}% interval (target {level}%)</span></div>
      <div class="stat"><span class="stat-v">{Math.round(width).toLocaleString()}</span><span class="stat-l">median interval width, bikes per day</span></div>
      <table class="mae">
        <caption>Point accuracy (MAE, bikes/day)</caption>
        <tbody>
          <tr><td>Poisson</td><td>{Math.round(maeP)}</td></tr>
          <tr><td>Negative binomial</td><td>{Math.round(maeN)}</td></tr>
          <tr><td>Naive (yesterday)</td><td>{Math.round(maeNaive)}</td></tr>
        </tbody>
      </table>
      <p class="note">{model === 'pois' ? 'The Poisson fan is a thin thread: it is honest only if the variance equals the mean.' : `Negative binomial: variance = μ + μ²/θ with θ = ${(+B.theta).toFixed(1)}. Its 95% interval still misses 13 days, among them Hurricane Sandy (Oct 29–30), Thanksgiving weekend and the Christmas holidays.`}</p>
    </div>
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 300px; }
  .side { display: grid; gap: .8rem; font-size: .84rem; }
  .bad { color: var(--danger) !important; }
  .mae { margin: 0; font-size: .8rem; font-variant-numeric: tabular-nums; }
  .mae caption { text-align: left; color: var(--muted); font-size: .76rem; padding-bottom: .2rem; }
  .mae td { padding: .25rem .4rem; } .mae td:last-child { text-align: right; font-weight: 650; }
  .note { margin: 0; color: var(--muted); font-size: .78rem; }
</style>
