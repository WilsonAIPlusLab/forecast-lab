<script lang="ts">
  // Scrollytelling: a sticky chart of NSA retail sales that comes apart into trend, seasonal and remainder layers, then recombines.
  import { onMount } from 'svelte';
  import Scrolly from './Scrolly.svelte';
  import DecompFigure, { STEPS, type DecompModel } from './DecompFigure.svelte';
  import { loadSeries } from '../../lib/ts';
  import { stl } from './stl';
  import './viz';

  let step = $state(0);
  let model: DecompModel | null = $state(null);
  let staticMode = $state(false);
  let nums = $state({ nsa: 0, sa: 0, off: 0, dec: 0, feb: 0, apr20: 0, mar21: 0, year: 2025 });

  onMount(async () => {
    // ?static in the URL opens the story as static figures (handy for slides and screen readers)
    if (new URLSearchParams(location.search).has('static')) staticMode = true;
    const [r, a, f] = await Promise.all([loadSeries('RSXFSN', { start: '2005-01-01' }), loadSeries('RSAFS', { start: '2005-01-01' }), loadSeries('RSFSDP', { start: '2005-01-01' })]);
    const y = r.data.map((p) => Math.log(p.value));
    // Same settings as the code lab: stl(log(retail), s.window = 13, robust = TRUE), fitted on 2005 onward
    const fit = stl(y, { period: 12, sWindow: 13, robust: true });
    const key = (d: Date) => `${d.getFullYear()}-${d.getMonth()}`;
    const fs = new Map(f.data.map((p) => [key(p.date), p.value]));
    const off = new Map(a.data.map((p) => [key(p.date), fs.has(key(p.date)) ? p.value - fs.get(key(p.date))! : null]));
    const from = r.data.findIndex((p) => p.date.getFullYear() >= 2015);
    const sl = (arr: any[]) => arr.slice(from);
    const m: DecompModel = {
      dates: sl(r.data.map((p) => p.date)), data: sl(r.data.map((p) => p.value)),
      trend: sl(fit.trend.map(Math.exp)), seasonal: sl(fit.seasonal), remainder: sl(fit.remainder),
      official: sl(r.data.map((p) => off.get(key(p.date)) ?? null)),
    };
    const at = (yy: number, mm: number) => m.dates.findIndex((d) => d.getFullYear() === yy && d.getMonth() === mm);
    const decs = m.dates.map((d, i) => (d.getMonth() === 11 ? i : -1)).filter((i) => i >= 0);
    const ld = decs[decs.length - 1], yr = m.dates[ld].getFullYear();
    const sa = (i: number) => m.data[i] / Math.exp(m.seasonal[i]);
    const p = (v: number) => 100 * (Math.exp(v) - 1);
    nums = {
      nsa: 100 * (m.data[ld] / m.data[ld - 1] - 1), sa: 100 * (sa(ld) / sa(ld - 1) - 1),
      off: m.official[ld] != null && m.official[ld - 1] != null ? 100 * ((m.official[ld] as number) / (m.official[ld - 1] as number) - 1) : NaN,
      dec: p(m.seasonal[ld]), feb: p(m.seasonal[at(yr, 1)]), apr20: p(m.remainder[at(2020, 3)]), mar21: p(m.remainder[at(2021, 2)]), year: yr,
    };
    model = m;
  });

  const f1 = (v: number) => (v > 0 ? '+' : v < 0 ? '−' : '') + Math.abs(v).toFixed(1) + '%';
  const texts = $derived([
    `This is U.S. retail sales (excluding restaurants and bars), every month since 2015, <b>not seasonally adjusted</b>. It looks like the blade of a saw.`,
    `The tallest tooth every year is December. In December ${nums.year}, sales jumped <b>${f1(nums.nsa)}</b> from November. A headline writer's dream. But is it news?`,
    `Underneath runs a slow-moving <b class="c-t">trend</b>: roughly the level sales would have if every month were an average month. STL estimates it with local regression (loess).`,
    `Now pull the series apart. STL sorts every month into three layers that slide apart: <b class="c-t">trend</b>, <b class="c-s">seasonal</b> and <b class="c-r">remainder</b>. Watch each line peel off the data.`,
    `The <b class="c-s">seasonal</b> layer repeats every year. A typical December now sits <b>${Math.abs(nums.dec).toFixed(1)}%</b> above trend, a typical February <b>${Math.abs(nums.feb).toFixed(1)}%</b> below. STL lets this shape drift slowly over the years.`,
    `The <b class="c-r">remainder</b> is what neither trend nor season explains: the April 2020 lockdowns (<b>${f1(nums.apr20)}</b>) and the March 2021 stimulus checks (<b>${f1(nums.mar21)}</b>). This is where the news lives.`,
    `Put the layers back together (trend × seasonal × remainder) and you get the original series <b>exactly</b>. Nothing was lost. It was only sorted.`,
    `Remove only the seasonal layer and you have the <b class="c-sa">seasonally adjusted</b> series. December ${nums.year}: <b>${f1(nums.sa)}</b> on our adjustment, <b>${f1(nums.off)}</b> on the Census Bureau's, not ${f1(nums.nsa)}. December was a normal December.`,
  ]);
  const plain = (h: string) => h.replace(/<[^>]+>/g, '');
</script>

<div class="dsc">
  <div class="dsc-top">
    <span class="kick">Scroll story: U.S. retail sales, NSA, $ millions per month</span>
    <button class="btn btn-ghost btn-sm" onclick={() => (staticMode = !staticMode)} aria-pressed={staticMode}>{staticMode ? 'Show as scroll story' : 'Show as static figures'}</button>
  </div>
  {#if !model}
    <div class="loading" aria-live="polite">Loading retail sales and running STL…</div>
  {:else if staticMode}
    <ol class="static">
      {#each STEPS as _, i}
        <li>
          <p>{@html texts[i]}</p>
          <DecompFigure {model} step={i} animate={false} label={plain(texts[i])} />
        </li>
      {/each}
    </ol>
  {:else}
    <div class="scrolly">
      <div class="sticky">
        <DecompFigure {model} {step} label={plain(texts[step])} />
        <div class="progress" aria-hidden="true">{#each STEPS as _, i}<span class:on={i === step}></span>{/each}</div>
      </div>
      <div class="steps">
        <Scrolly bind:value={step}>
          {#each texts as t, i}
            <div class="step" class:active={i === step}><div class="card"><span class="n">{i + 1}/{texts.length}</span><p>{@html t}</p></div></div>
          {/each}
        </Scrolly>
      </div>
    </div>
  {/if}
  <p class="src">Source: U.S. Census Bureau via FRED (RSXFSN; Census SA = RSAFS − RSFSDP). Decomposition: STL on log sales, s.window = 13, robust, fitted on 2005 onward (exactly what the code lab below runs).</p>
</div>

<style>
  .dsc { margin: 2.4rem 0; }
  .dsc-top { display: flex; justify-content: space-between; align-items: center; gap: 1rem; flex-wrap: wrap; margin-bottom: .6rem; }
  .kick { font-size: .84rem; font-weight: 650; color: var(--ch, var(--accent-2)); }
  .loading { padding: 3rem 1rem; color: var(--muted); text-align: left; }
  .scrolly { display: grid; grid-template-columns: minmax(0, 2.1fr) minmax(240px, 1fr); gap: 2rem; align-items: start; }
  .sticky { position: sticky; top: calc(var(--header-h, 64px) + 18px); background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius); padding: 1rem 1rem .6rem; }
  .steps { padding: 18vh 0 30vh; }
  .step { min-height: 72vh; display: flex; align-items: center; }
  .step:last-child { min-height: 60vh; }
  .card { background: var(--surface); border: 1px solid var(--border); border-left: 3px solid var(--border-strong); border-radius: 10px; padding: 1rem 1.1rem; font-size: 1rem; line-height: 1.6; color: var(--text-2); opacity: .55; transition: opacity 300ms, border-color 300ms; }
  .step.active .card { opacity: 1; border-left-color: var(--ch, var(--accent)); }
  .card p { margin: 0; }
  .n { display: block; font-size: .78rem; color: var(--muted); font-variant-numeric: tabular-nums; margin-bottom: .3rem; }
  .card :global(b) { color: var(--text); }
  .card :global(.c-t), .static :global(.c-t) { color: var(--c-s1); }
  .card :global(.c-s), .static :global(.c-s) { color: var(--c-s3); }
  .card :global(.c-r), .static :global(.c-r) { color: var(--c-s2); }
  .card :global(.c-sa), .static :global(.c-sa) { color: var(--c-fitted); }
  .progress { display: flex; gap: 4px; margin-top: .5rem; }
  .progress span { flex: 1; height: 3px; border-radius: 2px; background: var(--border); transition: background 300ms; }
  .progress span.on { background: var(--ch, var(--accent)); }
  .static { list-style: none; padding: 0; display: grid; gap: 1.6rem; }
  .static li { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius); padding: 1rem; }
  .static p { margin: 0 0 .6rem; color: var(--text-2); }
  .src { font-size: .78rem; color: var(--muted); margin-top: .8rem; }
  @media (max-width: 860px) {
    .scrolly { grid-template-columns: 1fr; gap: 0; }
    .sticky { top: calc(var(--header-h, 56px) + 6px); z-index: 2; max-height: 60vh; overflow: hidden; padding: .5rem; }
    .steps { padding: 0; position: relative; z-index: 3; }
    .step { min-height: 85vh; align-items: flex-end; padding-bottom: 6vh; }
    .card { opacity: .96; box-shadow: var(--shadow); }
  }
  @media (prefers-reduced-motion: reduce) { .card, .progress span { transition: none; } }
</style>
