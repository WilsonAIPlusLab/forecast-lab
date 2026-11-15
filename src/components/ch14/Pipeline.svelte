<script lang="ts">
  // The professional forecasting pipeline as a nine-step roadmap. Each step links back to the chapter that teaches it,
  // and doubles as a checklist students can tick off for their own forecast (saved in this browser only).
  import { onMount } from 'svelte';
  import { bySlug } from '../../lib/chapters';
  import { BASE } from '../../lib/runtime/status';

  interface Step { name: string; short: string; do: string; deliver: string; flag: string; ch: string[]; anchor?: string }
  const STEPS: Step[] = [
    { name: 'Define the decision and the loss', short: 'Decision', ch: ['benchmarks', 'uncertainty'],
      do: 'Write one sentence: who uses the forecast, for which decision, how far ahead, and which mistake costs more, too high or too low.',
      deliver: 'A spec line such as “Monthly retail sales, 12 months ahead, judged by MAE; over-forecasts cost us excess stock.”',
      flag: 'Nobody can name the decision the forecast feeds.' },
    { name: 'Get and inspect the data', short: 'Data', ch: ['time-series-data', 'decomposition', 'dynamic-regression'],
      do: 'Plot it before anything else. Check units, frequency, seasonally adjusted or not (SA/NSA), revisions, outliers and breaks such as 2020.',
      deliver: 'One annotated plot and a short data note: source, FRED ID, units, SA/NSA, sample.',
      flag: 'Mixing SA and NSA data, or $ millions with $ billions.' },
    { name: 'Benchmark', short: 'Benchmark', ch: ['benchmarks'],
      do: 'Run naive, seasonal naive and drift. They take one line each and set the bar.',
      deliver: 'The first rows of your scorecard.',
      flag: 'A model reported with no benchmark beside it.' },
    { name: 'Fit candidate models', short: 'Models', ch: ['exponential-smoothing', 'arima', 'regression', 'dynamic-regression', 'random-forests', 'boosting-shap'],
      do: 'Try a few different families: ETS, ARIMA, regression or dynamic regression with drivers, and a tree ensemble on lag features.',
      deliver: 'One forecast per model, all for the same horizon and the same cut-off date.',
      flag: 'Twenty variants of one model and no other family.' },
    { name: 'Evaluate on rolling origins, by horizon', short: 'Evaluate', ch: ['benchmarks'],
      do: 'Re-fit and forecast from many past origins (tsCV). Report error at each horizon, not one number.',
      deliver: 'A scorecard (MAE, RMSE, MASE, bias) and an error-by-horizon chart.',
      flag: 'One lucky test period, or choosing the model on the test set.' },
    { name: 'Combine', short: 'Combine', ch: ['uncertainty'],
      do: 'Average two to four good, different models. Equal weights are hard to beat.',
      deliver: 'A combination row in the scorecard.',
      flag: 'Averaging in a model that cannot handle the seasonality.' },
    { name: 'Intervals and coverage', short: 'Intervals', ch: ['uncertainty'],
      do: 'Give 80% (and often 95%) ranges, and check how often past ranges actually caught the outcome.',
      deliver: 'A fan chart and a coverage audit.',
      flag: 'A point forecast with no range, or “80%” ranges that catch half the outcomes.' },
    { name: 'Explain', short: 'Explain', ch: ['regression', 'boosting-shap'],
      do: 'Say what drives the forecast: coefficients and scenarios for regression, SHAP values for machine learning.',
      deliver: 'Two or three drivers in plain words, with a scenario if useful.',
      flag: '“The model says so.”' },
    { name: 'Communicate', short: 'Communicate', ch: ['forecast-studio'], anchor: '#communicate',
      do: 'Bottom line first. One chart, one number, one range, one risk, and what would change your view.',
      deliver: 'A one-paragraph executive summary and a slide-ready chart.',
      flag: 'A 20-slide deck of diagnostics and no answer.' },
  ];

  let cur = $state(0);
  let done: boolean[] = $state(STEPS.map(() => false));
  const KEY = 'fl-ch14-pipeline';
  onMount(() => { try { const v = JSON.parse(localStorage.getItem(KEY) || '[]'); if (Array.isArray(v) && v.length === STEPS.length) done = v.map(Boolean); } catch {} });
  function setDone(i: number, v: boolean) { done[i] = v; try { localStorage.setItem(KEY, JSON.stringify(done)); } catch {} }
  function key(e: KeyboardEvent) {
    const k = e.key === 'ArrowRight' || e.key === 'ArrowDown' ? 1 : e.key === 'ArrowLeft' || e.key === 'ArrowUp' ? -1 : 0;
    if (!k) return; e.preventDefault(); cur = (cur + k + STEPS.length) % STEPS.length;
    (document.getElementById(`pl-tab-${cur}`) as HTMLElement | null)?.focus();
  }
  const nDone = $derived(done.filter(Boolean).length);
  const link = (slug: string, anchor = '') => `${BASE}chapters/${slug}/${anchor}`;
  const s = $derived(STEPS[cur]);
</script>

<figure class="pl" aria-label="The forecasting pipeline in nine steps">
  <div class="pl-top">
    <span class="pl-k">The pipeline</span>
    <span class="pl-p" aria-live="polite">{nDone} of {STEPS.length} ticked for your forecast</span>
  </div>
  <div class="track" role="tablist" aria-label="Pipeline steps" tabindex="-1" onkeydown={key}>
    {#each STEPS as st, i}
      <button id="pl-tab-{i}" role="tab" class="node" class:on={cur === i} class:done={done[i]} aria-selected={cur === i} aria-controls="pl-panel" tabindex={cur === i ? 0 : -1} onclick={() => (cur = i)}>
        <span class="dot">{done[i] ? '✓' : i + 1}</span>
        <span class="nm">{st.short}</span>
      </button>
    {/each}
  </div>
  <div class="panel" id="pl-panel" role="tabpanel" aria-labelledby="pl-tab-{cur}">
    <div class="ph">
      <h4>{cur + 1}. {s.name}</h4>
      <label class="tick"><input type="checkbox" checked={done[cur]} onchange={(e) => setDone(cur, (e.currentTarget as HTMLInputElement).checked)} /> Done for my forecast</label>
    </div>
    <dl>
      <div><dt>Do</dt><dd>{s.do}</dd></div>
      <div><dt>Deliver</dt><dd>{s.deliver}</dd></div>
      <div><dt>Red flag</dt><dd>{s.flag}</dd></div>
    </dl>
    <p class="learn">Learn it in:
      {#each s.ch as c, j}{@const ch = bySlug(c)}<a href={link(c, s.anchor ?? '')}>Ch. {ch.n} {ch.short}</a>{j < s.ch.length - 1 ? ', ' : ''}{/each}
    </p>
    <div class="nav">
      <button class="btn btn-ghost btn-sm" disabled={cur === 0} onclick={() => (cur -= 1)}>Previous step</button>
      <button class="btn btn-sm" disabled={cur === STEPS.length - 1} onclick={() => (cur += 1)}>Next step</button>
    </div>
  </div>
</figure>

<style>
  .pl { margin: 2.2rem 0; border: 1px solid var(--border); border-radius: var(--radius); background: var(--surface); padding: 1rem 1.2rem 1.1rem; }
  .pl-top { display: flex; justify-content: space-between; align-items: baseline; gap: 1rem; flex-wrap: wrap; margin-bottom: .8rem; }
  .pl-k { font-size: .8rem; font-weight: 650; color: var(--ch, var(--accent-text)); }
  .pl-p { font-size: .78rem; color: var(--muted); font-variant-numeric: tabular-nums; }
  .track { display: grid; grid-template-columns: repeat(9, minmax(0, 1fr)); position: relative; gap: 0; }
  .track::before { content: ''; position: absolute; left: 5.5%; right: 5.5%; top: 17px; height: 2px; background: var(--border-strong); }
  .node { all: unset; cursor: pointer; position: relative; display: flex; flex-direction: column; align-items: center; gap: .4rem; padding: 0 .1rem .3rem; border-radius: 8px; }
  .node:focus-visible { outline: 2px solid var(--accent-2); outline-offset: 2px; }
  .dot { width: 34px; height: 34px; border-radius: 50%; display: grid; place-items: center; font: 700 .84rem var(--font-ui); font-variant-numeric: tabular-nums; background: var(--bg-2); border: 2px solid var(--border-strong); color: var(--text-2); transition: background-color .2s, border-color .2s, color .2s; }
  .node.done .dot { border-color: var(--good); color: var(--good); }
  .node.on .dot { background: var(--ch, var(--accent)); border-color: var(--ch, var(--accent)); color: var(--bg); }
  .nm { font-size: .74rem; font-weight: 600; color: var(--muted); text-align: center; line-height: 1.25; }
  .node.on .nm { color: var(--text); }
  @media (max-width: 720px) {
    .track { grid-template-columns: repeat(5, minmax(0, 1fr)); row-gap: .8rem; }
    .track::before { display: none; }
  }
  .panel { margin-top: 1rem; border-top: 1px solid var(--border); padding-top: .9rem; }
  .ph { display: flex; justify-content: space-between; align-items: baseline; gap: 1rem; flex-wrap: wrap; }
  .ph h4 { margin: 0; font: 650 1.05rem var(--font-ui); color: var(--text); }
  .tick { display: inline-flex; align-items: center; gap: .4rem; font-size: .8rem; color: var(--text-2); cursor: pointer; }
  .tick input { accent-color: var(--good); }
  dl { display: grid; gap: .5rem; margin: .8rem 0; }
  dl div { display: grid; grid-template-columns: 6rem 1fr; gap: .8rem; }
  dt { font-size: .78rem; font-weight: 700; color: var(--muted); padding-top: .12rem; }
  dd { margin: 0; font-size: .92rem; color: var(--text-2); line-height: 1.55; }
  @media (max-width: 560px) { dl div { grid-template-columns: 1fr; gap: .1rem; } }
  .learn { font-size: .86rem; color: var(--text-2); margin: 0 0 .8rem; }
  .nav { display: flex; gap: .5rem; }
  @media (prefers-reduced-motion: reduce) { .dot { transition: none; } }
</style>
