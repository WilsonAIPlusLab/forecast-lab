<script lang="ts">
  // "One change at a time": climb from the naive rule to Holt-Winters multiplicative, adding ONE ingredient per rung,
  // and see how much each ingredient lowers (or raises) the rolling-origin error on the chosen series.
  // Same engine and 48 rolling origins as the Forecast Studio, so the numbers match its scorecard.
  import Explorable from '../Explorable.svelte';
  import { loadSeries } from '../../lib/ts';
  import { runStudio, type ModelKey, type StudioResult } from './engine';
  import { STUDIO_SERIES, seriesById, fmtShort, fmtMiss } from './series';

  const RUNGS: { k: ModelKey; name: string; change: string }[] = [
    { k: 'naive', name: 'Naive', change: 'Start: copy the last value' },
    { k: 'ses', name: 'Simple exp. smoothing', change: '+ smoothing: a weighted average of recent months' },
    { k: 'holt', name: 'Holt (damped trend)', change: '+ a trend that flattens out' },
    { k: 'hwa', name: 'Holt-Winters additive', change: '+ seasonality of fixed size' },
    { k: 'hwm', name: 'Holt-Winters multiplicative', change: 'seasonal swings scale with the level' },
  ];
  const START = '2010-01-01';

  let sid = $state('RSXFSN');
  let horizon: 'avg' | 'one' = $state('avg');
  let res: StudioResult | null = $state(null);
  let lastLabel = $state('');
  const meta = $derived(seriesById(sid));

  let seq = 0;
  $effect(() => {
    const id = sid, my = ++seq;
    loadSeries(id, { start: START }).then((s) => {
      if (my !== seq) return;
      const y = s.data.map((p) => p.value / seriesById(id).div);
      lastLabel = s.data[s.data.length - 1].date.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
      res = runStudio(y, 12, ['naive', 'snaive', 'drift', 'ses', 'holt', 'hwa', 'hwm'], 12, 48);
    });
  });

  const err = (k: ModelKey) => { const sc = res!.scores.find((x) => x.k === k)!; return horizon === 'avg' ? sc.MAE : sc.maeH[0]; };
  const view = $derived.by(() => {
    if (!res) return null;
    const rows = RUNGS.map((r, i) => {
      const v = err(r.k), prev = i ? err(RUNGS[i - 1].k) : NaN;
      return { ...r, v, d: i ? v / prev - 1 : 0 };
    });
    const sn = err('snaive'), dr = err('drift');
    const max = Math.max(...rows.map((r) => r.v), sn, dr) * 1.06;
    const helped = rows.slice(1).filter((r) => r.d < -0.05).length;
    const hurt = rows.slice(1).filter((r) => r.d > 0.05).length;
    const best = rows.slice().sort((a, b) => a.v - b.v)[0];
    const bench = sn <= dr ? { name: 'Seasonal naive', v: sn } : { name: 'Drift', v: dr };
    const naiveV = rows[0].v;
    const bestBench = naiveV < bench.v ? { name: 'Naive', v: naiveV } : bench;
    return { rows, sn, dr, max, helped, hurt, best, bestBench };
  });
  const pct = (d: number) => `${d < 0 ? '−' : '+'}${Math.abs(d * 100).toFixed(0)}%`;
  const verdict = (d: number) => (d < -0.05 ? 'helped' : d > 0.05 ? 'hurt' : 'tie');
  const ariaChart = $derived(view ? `Rolling-origin error of five methods on ${meta.label}, each adding one ingredient: ` +
    view.rows.map((r) => `${r.name} ${fmtShort(meta, r.v)}`).join(', ') + `. Seasonal naive benchmark ${fmtShort(meta, view.sn)}.` : 'Loading');
</script>

<Explorable title="Add one ingredient at a time, and keep only what pays" caption="Each rung adds <b>one</b> ingredient to the rung above it and is scored on the same 48 rolling origins as the Forecast Studio (data through the latest month, forecasts 1 to 12 months ahead). Bars show the typical miss (MAE) in the series' own units; the dashed lines are two benchmarks. A change that lowers the error by more than 5% <b>helped</b>; one that raises it by more than 5% <b>hurt</b>; anything in between is a tie. Because only one thing changes per rung, you know exactly what each ingredient bought.">
  {#snippet controls()}
    <label class="sel">Series
      <select bind:value={sid} aria-label="Series">
        {#each STUDIO_SERIES as s}<option value={s.id}>{s.label} ({s.adj})</option>{/each}
      </select>
    </label>
    <div class="seg" role="group" aria-label="Error measured">
      <button class:on={horizon === 'avg'} aria-pressed={horizon === 'avg'} onclick={() => (horizon = 'avg')}>Average, 1–12 months ahead</button>
      <button class:on={horizon === 'one'} aria-pressed={horizon === 'one'} onclick={() => (horizon = 'one')}>1 month ahead</button>
    </div>
  {/snippet}
  {#snippet aside()}
    {#if view}
      <div class="rd">
        <div class="stat"><span class="stat-v">{view.helped} of 4</span><span class="stat-l">ingredients helped (more than 5% lower error)</span></div>
        <p class="cmp">Best rung: <b>{view.best.name}</b>, typical miss {fmtMiss(meta, view.best.v)}. Best simple benchmark: <b>{view.bestBench.name}</b>, {fmtMiss(meta, view.bestBench.v)}.</p>
        <p class="cmp">{#if view.best.v < 0.95 * view.bestBench.v}The ladder beats the best benchmark by {Math.round((1 - view.best.v / view.bestBench.v) * 100)}%: the extra ingredients earn their keep.{:else}No rung beats the best benchmark by more than 5%. Ship the benchmark and say so.{/if}</p>
        <p class="hint">{meta.label} is {meta.adj === 'SA' ? 'seasonally adjusted: adding seasonality should buy little or nothing' : 'not seasonally adjusted: watch the seasonality rung'}. Data through {lastLabel}.</p>
      </div>
    {/if}
  {/snippet}
  <div class="lad" role="img" aria-label={ariaChart}>
    {#if view}
      {#each view.rows as r, i}
        <div class="row">
          <div class="lbl"><span class="nm">{i + 1}. {r.name}</span><span class="ch">{r.change}</span></div>
          <div class="track">
            <div class="bar" class:helped={i > 0 && verdict(r.d) === 'helped'} class:hurt={i > 0 && verdict(r.d) === 'hurt'} style="width: {(r.v / view.max) * 100}%"></div>
            <span class="ref" style="left: {(view.sn / view.max) * 100}%" aria-hidden="true"></span>
            <span class="ref dr" style="left: {(view.dr / view.max) * 100}%" aria-hidden="true"></span>
          </div>
          <div class="val">
            <b>{fmtShort(meta, r.v)}</b>
            {#if i > 0}<span class="dl {verdict(r.d)}">{pct(r.d)} {verdict(r.d) === 'helped' ? '✓ helped' : verdict(r.d) === 'hurt' ? '✗ hurt' : '≈ tie'}</span>{:else}<span class="dl">starting point</span>{/if}
          </div>
        </div>
      {/each}
      <div class="row legend" aria-hidden="true">
        <div class="lbl"></div>
        <div class="track keys">
          <span><i class="k sn"></i>Seasonal naive {fmtShort(meta, view.sn)}</span>
          <span><i class="k drk"></i>Drift {fmtShort(meta, view.dr)}</span>
        </div>
        <div class="val"><span class="dl">MAE, {meta.unitAxis}</span></div>
      </div>
    {:else}
      <p class="load">Scoring five methods on 48 rolling origins…</p>
    {/if}
  </div>
</Explorable>

<style>
  .sel { display: inline-flex; align-items: center; gap: .5rem; }
  .sel select { font: 600 .8rem var(--font-ui); padding: .3rem .5rem; border-radius: 8px; border: 1px solid var(--border); background: var(--bg); color: var(--text); max-width: 100%; }
  .lad { display: flex; flex-direction: column; gap: .7rem; min-height: 300px; }
  .row { display: grid; grid-template-columns: minmax(150px, 1.1fr) 2fr minmax(92px, auto); gap: .8rem; align-items: center; }
  .lbl { display: flex; flex-direction: column; gap: .1rem; }
  .nm { font: 650 .86rem var(--font-ui); color: var(--text); }
  .ch { font-size: .78rem; color: var(--muted); line-height: 1.3; }
  .track { position: relative; height: 26px; background: var(--bg-2); border-radius: 6px; }
  .bar { position: absolute; left: 0; top: 0; bottom: 0; border-radius: 6px; background: var(--c-history); opacity: .55; transition: width .35s ease; }
  .bar.helped { background: var(--good); opacity: .8; }
  .bar.hurt { background: var(--danger); opacity: .75; }
  .ref { position: absolute; top: -4px; bottom: -4px; border-left: 2px dashed var(--c-actual); }
  .ref.dr { border-left-color: var(--c-fitted); border-left-style: dotted; }
  .val { display: flex; flex-direction: column; font-variant-numeric: tabular-nums; }
  .val b { font: 650 .95rem var(--font-ui); color: var(--text); }
  .dl { font-size: .76rem; color: var(--muted); }
  .dl.helped { color: var(--good); font-weight: 650; }
  .dl.hurt { color: var(--danger); font-weight: 650; }
  .legend .track { background: none; height: auto; }
  .keys { display: flex; flex-wrap: wrap; gap: .3rem 1rem; font-size: .78rem; color: var(--text-2); }
  .k { display: inline-block; width: 0; height: 12px; margin-right: .35rem; vertical-align: -1px; }
  .k.sn { border-left: 2px dashed var(--c-actual); }
  .k.drk { border-left: 2px dotted var(--c-fitted); }
  .rd { display: flex; flex-direction: column; gap: .8rem; font-size: .84rem; }
  .cmp { margin: 0; color: var(--text-2); }
  .hint { margin: 0; color: var(--muted); font-size: .78rem; }
  .load { color: var(--muted); font-size: .85rem; }
  @media (max-width: 560px) {
    .row { grid-template-columns: 1fr auto; }
    .lbl { grid-column: 1 / -1; }
    .legend .lbl { display: none; }
  }
  @media (prefers-reduced-motion: reduce) { .bar { transition: none; } }
</style>
