<script lang="ts">
  import { onMount } from 'svelte';
  import Explorable from '../Explorable.svelte';
  import { loadSeries } from '../../lib/ts';
  import { watchLayout } from '../../lib/viz/theme';
  import { renderSpec } from '../../lib/viz/render';
  import { ols, key } from './lib';
  import './viz';

  // ADL impulse: estimate dj_t = a + Σφ_i dj_{t-i} + Σβ_j dcl_{t-j} on 1990–2019 in the browser,
  // then push a one-time jump in claims through the fitted equation.
  let p = $state(2);
  let q = $state(3);
  let shock = $state(10);
  let dj: number[] = [], dcl: number[] = [], dates: string[] = [];
  let ready = $state(false);
  let el: HTMLDivElement;
  const H = 24;

  onMount(() => {
    (async () => {
      const [pay, cl] = await Promise.all([loadSeries('PAYEMS'), loadSeries('ICSA', { to: 'month' })]);
      const c = new Map(cl.data.map((d, i) => [key(d.date), i ? 100 * Math.log(d.value / cl.data[i - 1].value) : NaN]));
      const rows = pay.data.slice(1).map((d, i) => ({ k: key(d.date), dj: d.value - pay.data[i].value, dcl: c.get(key(d.date)) ?? NaN })).filter((r) => Number.isFinite(r.dcl));
      dj = rows.map((r) => r.dj); dcl = rows.map((r) => r.dcl); dates = rows.map((r) => r.k);
      ready = true;
    })();
    return watchLayout(el, draw);
  });

  const model = $derived.by(() => {
    if (!ready) return null;
    const X: number[][] = [], Y: number[] = [];
    for (let t = 0; t < dates.length; t++) {
      if (dates[t] < '1990-01' || dates[t] > '2019-12') continue;
      const row = [1];
      for (let i = 1; i <= p; i++) row.push(dj[t - i]);
      for (let j = 0; j <= q; j++) row.push(dcl[t - j]);
      X.push(row); Y.push(dj[t]);
    }
    const f = ols(X, Y);
    const phi = f.beta.slice(1, 1 + p), beta = f.beta.slice(1 + p);
    const irf: number[] = [];
    for (let h = 0; h <= H; h++) {
      let v = h <= q ? beta[h] : 0;
      for (let i = 1; i <= p; i++) if (h - i >= 0) v += phi[i - 1] * irf[h - i];
      irf.push(v);
    }
    const sphi = phi.reduce((a, b) => a + b, 0), sb = beta.reduce((a, b) => a + b, 0);
    const bic = f.n * Math.log(f.rss / f.n) + f.k * Math.log(f.n);
    return { irf, lr: sphi < 1 ? sb / (1 - sphi) : NaN, bic, beta, phi };
  });

  // BIC of every (p, q) combination, to show which one the data prefer.
  const bestBic = $derived.by(() => {
    if (!ready) return null;
    let best = { p: 0, q: 0, bic: Infinity };
    for (let pp = 0; pp <= 4; pp++) for (let qq = 0; qq <= 6; qq++) {
      const X: number[][] = [], Y: number[] = [];
      for (let t = 0; t < dates.length; t++) {
        if (dates[t] < '1990-01' || dates[t] > '2019-12') continue;
        const row = [1]; for (let i = 1; i <= pp; i++) row.push(dj[t - i]); for (let j = 0; j <= qq; j++) row.push(dcl[t - j]);
        X.push(row); Y.push(dj[t]);
      }
      const f = ols(X, Y), b = f.n * Math.log(f.rss / f.n) + f.k * Math.log(f.n);
      if (b < best.bic) best = { p: pp, q: qq, bic: b };
    }
    return best;
  });

  function draw() {
    if (!el || !model) return;
    const v = model.irf.map((x) => shock * x);
    let s = 0; const cum = v.map((x) => (s += x));
    renderSpec({ type: 'ch07-multipliers', h: Array.from({ length: H + 1 }, (_, i) => i), value: v, cumulative: cum, ylab: 'thousands of jobs', source: 'FRED (ICSA, PAYEMS); ADL estimated on 1990–2019 in your browser' }, el, { animate: false });
  }
  $effect(() => { model; shock; draw(); });

  const f1 = (x: number) => (Number.isFinite(x) ? (x < 0 ? '−' : '') + Math.abs(Math.round(x)).toLocaleString() : '—');
  const cum12 = $derived(model ? shock * model.irf.slice(0, 13).reduce((a, b) => a + b, 0) : 0);
</script>

<Explorable title="Push claims up once and watch the jobs response ripple out" caption={`The model is an ADL(<i>p</i>, <i>q</i>): this month's job gains depend on job gains in the previous <i>p</i> months and on claims growth this month and in the previous <i>q</i> months. It is re-estimated by OLS on 1990–2019 every time you move a slider. Bars show how many fewer (or more) jobs are added each month after claims rise once by the chosen percentage and stay at the new level; the line is the running total, which is the effect on the number of people employed. Data: FRED (PAYEMS, ICSA), seasonally adjusted.`}>
  {#snippet controls()}
    <label class="sl">Lags of jobs, <i>p</i> <input type="range" min="0" max="4" step="1" bind:value={p} aria-label="Number of lags of job gains" aria-valuetext={`${p} lags`} /> <b>{p}</b></label>
    <label class="sl">Lags of claims, <i>q</i> <input type="range" min="0" max="6" step="1" bind:value={q} aria-label="Number of lags of claims growth" aria-valuetext={`${q} lags`} /> <b>{q}</b></label>
    <label class="sl">Claims jump <input type="range" min="5" max="50" step="5" bind:value={shock} aria-label="Size of the jump in claims" aria-valuetext={`${shock} percent`} /> <b>{shock}%</b></label>
  {/snippet}
  {#snippet aside()}
    {#if model}
      <div class="ro" aria-live="polite">
        <div class="stat"><span class="stat-v">{f1(shock * model.beta[0])}k</span><span class="stat-l">impact: jobs added in the same month</span></div>
        <div class="stat"><span class="stat-v">{f1(cum12)}k</span><span class="stat-l">total after 12 months</span></div>
        <div class="stat"><span class="stat-v">{f1(shock * model.lr)}k</span><span class="stat-l">long run: Σβ / (1 − Σφ) × {shock}</span></div>
        <p class="note">BIC {model.bic.toFixed(0)} (lower is better).{#if bestBic}{' '}The data prefer <b>p = {bestBic.p}, q = {bestBic.q}</b>.{/if} Set <i>p</i> = 0 and the echo disappears: the response stops after month <i>q</i>.</p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 320px; }
  .ro { display: flex; flex-direction: column; gap: .75rem; font-size: .84rem; }
  .note { margin: 0; color: var(--text-2); }
</style>
