<script lang="ts">
  // The forecasting workflow as a map of the course: seven steps, a loop back from "evaluate"
  // to "model", and the chapters that teach each step.
  import { chapters } from '../../lib/chapters';
  import Explorable from '../Explorable.svelte';

  const base = import.meta.env.BASE_URL.replace(/\/?$/, '/');
  const STEPS = [
    { k: 'Ask', name: 'Ask the question', q: 'Who will use the forecast, for what decision, how far ahead, and how often?', example: 'A grocery chain needs next month’s sales by store, every Monday, to set staffing.', trap: 'Forecasting a number nobody needs, or at the wrong horizon.', ch: [0, 1, 14] },
    { k: 'Get', name: 'Get the data', q: 'Which series measure it? What are their units, frequency and adjustment? When are they released and revised?', example: 'Pull retail sales from FRED, check it is NSA in $ millions, note that the latest month is an advance estimate.', trap: 'Mixing nominal and real, SA and NSA, or averaging a flow that should be summed.', ch: [1, 13] },
    { k: 'Look', name: 'Look at it', q: 'Is there a trend? Seasonality? Breaks, outliers, missing months?', example: 'Plot it, then plot the YoY change. Spot December, COVID and the October 2025 gap.', trap: 'Fitting a model before plotting the data.', ch: [1, 2] },
    { k: 'Bench', name: 'Set a benchmark', q: 'What would a naive guess score? This is the bar every model must clear.', example: 'Seasonal naive: next December equals last December.', trap: 'Reporting a model’s accuracy with nothing to compare it to.', ch: [3] },
    { k: 'Model', name: 'Model', q: 'Which method fits the pattern and the decision?', example: 'Regression on drivers (linear or nonlinear), exponential smoothing, ARIMA, leading indicators, a recession logit, a VAR, a random forest or gradient boosting.', trap: 'Choosing the fanciest method instead of the one that beats the benchmark.', ch: [4, 5, 6, 7, 8, 9, 11, 12] },
    { k: 'Eval', name: 'Evaluate honestly', q: 'How does it do on data it never saw, at the horizon that matters? How wide is the uncertainty?', example: 'Rolling-origin cross-validation; MASE below 1; 80% intervals that cover about 80% of outcomes.', trap: 'Judging on in-sample fit, or leaking future data into the training set.', ch: [3, 10] },
    { k: 'Tell', name: 'Communicate', q: 'What does the decision-maker need to see? A number, a range, a scenario?', example: 'A fan chart plus one sentence: “We expect 3–5% growth; plan for 4%.”', trap: 'A point forecast with no range, or a chart with no takeaway.', ch: [10, 14] },
  ];
  let i = $state(1); // this chapter: "Get the data"
  const step = $derived(STEPS[i]);
  const chs = $derived(step.ch.map((n) => chapters.find((c) => c.n === n)!).filter(Boolean));
  function key(e: KeyboardEvent) {
    if (e.key === 'ArrowRight' || e.key === 'ArrowDown') { e.preventDefault(); i = Math.min(STEPS.length - 1, i + 1); (e.currentTarget as HTMLElement).parentElement?.querySelectorAll('button')[i]?.focus(); }
    if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') { e.preventDefault(); i = Math.max(0, i - 1); (e.currentTarget as HTMLElement).parentElement?.querySelectorAll('button')[i]?.focus(); }
  }
</script>

<Explorable kicker="Course map" title="The forecasting workflow, and where each step is taught" caption="Click a step (or use the arrow keys) to see the question it answers, a worked example, the classic mistake, and the chapters that cover it. Steps 5 and 6 form a loop: most real projects go around it several times.">
  <div class="track" role="tablist" aria-label="Forecasting workflow steps">
    {#each STEPS as s, j}
      <button role="tab" aria-selected={i === j} tabindex={i === j ? 0 : -1} class:on={i === j} class:here={j === 1 || j === 2} onclick={() => (i = j)} onkeydown={key}>
        <span class="n">{j + 1}</span><span class="nm">{s.name}</span>
        {#if j === 1}<span class="you">You are here</span>{/if}
      </button>
    {/each}
    <svg class="loop" viewBox="0 0 100 20" preserveAspectRatio="none" aria-hidden="true">
      <path d="M 78 2 C 78 18, 64 18, 64 2" fill="none" stroke="var(--muted)" stroke-width="1.2" stroke-dasharray="3 3" vector-effect="non-scaling-stroke" marker-end="url(#wf-arrow)" />
      <defs><marker id="wf-arrow" viewBox="0 0 10 10" refX="5" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 z" fill="var(--muted)" /></marker></defs>
    </svg>
  </div>
  <div class="detail" role="tabpanel" aria-live="polite">
    <div class="q"><span class="tag">Question</span>{step.q}</div>
    <div class="cols">
      <div><span class="tag">Example</span>{step.example}</div>
      <div><span class="tag warn">Classic mistake</span>{step.trap}</div>
    </div>
    <div class="chs">
      <span class="tag">Taught in</span>
      {#each chs as c}<a href={`${base}chapters/${c.slug}/`} style={`--c:${c.accent}`}><b>{c.n}</b> {c.short}</a>{/each}
    </div>
  </div>
</Explorable>

<style>
  .track { position: relative; display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); gap: .4rem; padding-bottom: 1.6rem; }
  .track button { all: unset; cursor: pointer; position: relative; display: flex; flex-direction: column; gap: .35rem; padding: .7rem .6rem .75rem; border: 1px solid var(--border); border-radius: 10px; background: var(--bg-2); transition: border-color .2s, background .2s; }
  .track button:not(:last-of-type)::after { content: ''; position: absolute; right: -.45rem; top: 1.35rem; width: .5rem; height: 1.5px; background: var(--border-strong); }
  .track button:hover { border-color: var(--border-strong); }
  .track button:focus-visible { outline: 2px solid var(--accent-2); outline-offset: 2px; }
  .track button.on { border-color: var(--ch, var(--accent-2)); background: var(--surface-2); }
  .n { font: 700 .8rem var(--font-ui); width: 1.5rem; height: 1.5rem; border-radius: 50%; display: grid; place-items: center; border: 1.5px solid var(--border-strong); color: var(--text-2); font-variant-numeric: tabular-nums; }
  .on .n { background: var(--ch, var(--accent-2)); border-color: transparent; color: #04121a; }
  .nm { font: 600 .82rem/1.3 var(--font-ui); color: var(--text); }
  .you { font-size: .7rem; font-weight: 650; color: var(--ch, var(--accent-2)); }
  .loop { position: absolute; left: 0; right: 0; bottom: 0; width: 100%; height: 1.5rem; }
  .detail { display: grid; gap: .9rem; padding-top: .4rem; font-size: .92rem; line-height: 1.55; color: var(--text-2); }
  .q { color: var(--text); font-size: 1rem; }
  .cols { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
  .tag { display: block; font-size: .74rem; font-weight: 700; color: var(--muted); margin-bottom: .2rem; }
  .tag.warn { color: var(--danger); }
  .chs { display: flex; flex-wrap: wrap; gap: .45rem; align-items: center; }
  .chs .tag { width: 100%; }
  .chs a { font-size: .82rem; padding: .3rem .65rem; border-radius: 8px; border: 1px solid color-mix(in srgb, var(--c) 45%, transparent); color: var(--text); text-decoration: none; background: color-mix(in srgb, var(--c) 10%, transparent); }
  .chs a:hover { background: color-mix(in srgb, var(--c) 22%, transparent); }
  .chs a b { color: var(--c); margin-right: .2rem; }
  @media (max-width: 760px) {
    .track { grid-template-columns: 1fr; padding-bottom: 0; }
    .track button { flex-direction: row; align-items: center; }
    .track button::after, .loop { display: none; }
    .cols { grid-template-columns: 1fr; }
  }
</style>
