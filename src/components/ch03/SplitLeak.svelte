<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, mean, rng, ym, type Pt } from '../../lib/ts';
  import { C, plotStyle, fmt, watchLayout } from '../../lib/viz/theme';

  // One simple rule, scored two ways. Rule: fill each hidden month with the nearest known month(s);
  // if there is a known month on both sides, average the two. With a RANDOM split the "after" side is
  // the future (leakage), so the rule looks brilliant. With a TIME split only the past is known,
  // so the rule becomes the naive forecast and its honest error is much larger.
  const SERIES = {
    PAYEMS: { label: 'Payroll jobs', unit: 'thousand jobs' },
    UNRATE: { label: 'Unemployment rate', unit: 'percentage points' },
  } as const;
  type Sid = keyof typeof SERIES;
  const N_TEST = 24;                          // 24 of the 120 months (2010-2019) are hidden: 20%

  let sid: Sid = $state('PAYEMS');
  let mode: 'random' | 'time' = $state('random');
  let seed = $state(1);
  let data: Pt[] = $state([]);
  let el: HTMLDivElement;

  async function load() {
    const id = sid;
    const s = await loadSeries(id, { start: '2010-01-01', end: '2019-12-01' });
    if (id !== sid) return;                   // a newer choice arrived while loading
    data = s.data;
  }

  // Which months are hidden (test) under each split
  function testSet(kind: 'random' | 'time', n: number, sd: number): Set<number> {
    if (kind === 'time') return new Set(Array.from({ length: N_TEST }, (_, i) => n - N_TEST + i));
    const r = rng(sd * 7919), idx = Array.from({ length: n - 2 }, (_, i) => i + 1);   // keep first and last month known
    for (let i = idx.length - 1; i > 0; i--) { const j = Math.floor(r.u() * (i + 1)); [idx[i], idx[j]] = [idx[j], idx[i]]; }
    return new Set(idx.slice(0, N_TEST));
  }
  // Apply the "nearest known month(s)" rule to every hidden month
  function score(kind: 'random' | 'time') {
    const y = data.map((p) => p.value), n = y.length, test = testSet(kind, n, seed);
    const rows = [...test].sort((a, b) => a - b).map((t) => {
      let b = t - 1; while (b >= 0 && test.has(b)) b--;
      let a = t + 1; while (a < n && test.has(a)) a++;
      const f = b >= 0 && a < n ? (y[b] + y[a]) / 2 : b >= 0 ? y[b] : y[a];
      return { t, date: data[t].date, actual: y[t], f, usedFuture: a < n };
    });
    return { rows, test, mae: mean(rows.map((r) => Math.abs(r.actual - r.f))) };
  }
  const res = $derived(data.length ? { random: score('random'), time: score('time') } : null);
  const cur = $derived(res ? res[mode] : null);

  function draw() {
    if (!el || !res || !cur) return;
    const known = data.filter((_, i) => !cur.test.has(i));
    const W = el.clientWidth;
    el.replaceChildren(Plot.plot({
      width: W, height: Math.max(260, Math.min(340, W * 0.45)), marginLeft: 58, marginRight: 14, marginTop: 16,
      style: plotStyle(), x: { label: null }, y: { grid: true, nice: true, tickFormat: fmt, label: `↑ ${SERIES[sid].unit}` },
      ariaLabel: `${SERIES[sid].label}, 2010 to 2019, with 24 hidden months chosen ${mode === 'random' ? 'at random' : 'at the end'} and filled in from the nearest known months`,
      marks: [
        Plot.lineY(data, { x: 'date', y: 'value', stroke: C.history, strokeWidth: 1.25, strokeOpacity: 0.4 }),
        Plot.dot(known, { x: 'date', y: 'value', r: 2, fill: C.s[0] }),
        Plot.ruleX(cur.rows, { x: 'date', y1: 'actual', y2: 'f', stroke: C.danger, strokeWidth: 2, strokeOpacity: 0.7 }),
        Plot.dot(cur.rows, { x: 'date', y: 'actual', r: 4, stroke: C.actual, strokeWidth: 2, fill: 'none' }),
        Plot.dot(cur.rows, { x: 'date', y: 'f', r: 3.2, fill: C.forecast }),
        Plot.tip(cur.rows, Plot.pointerX({ x: 'date', y: 'f', title: (r: any) => `${ym(r.date)} (hidden)\nActual: ${fmt(r.actual)}\nFilled in: ${fmt(r.f)}\nMiss: ${fmt(Math.abs(r.actual - r.f))} ${SERIES[sid].unit}${r.usedFuture ? '\nUsed a LATER month: leakage' : ''}` })),
      ],
    }));
  }

  $effect(() => { sid; load(); });
  $effect(() => { cur; draw(); });
  onMount(() => watchLayout(el, draw));

  const ratio = $derived(res && res.random.mae > 0 ? res.time.mae / res.random.mae : NaN);
  const peeks = $derived(cur ? cur.rows.filter((r) => r.usedFuture).length : 0);
  const unit = $derived(SERIES[sid].unit);
</script>

<Explorable title="A random split makes the same rule look far more accurate than it is" caption={`The rule is the same in both splits: fill each hidden month (gold ring) with the nearest known month, averaging the months on either side when there are two. With a <b>random</b> split, one of those neighbors is a <i>later</i> month, so the rule quietly uses the future. With a split <b>by time</b>, only the past is known, the rule becomes the naive forecast, and you see the honest error. Press <b>Shuffle</b> a few times: the random-split MAE moves around, but it stays far below the honest one (for payrolls, 20 to 30 times smaller). Data: FRED ${sid}, 2010–2019, seasonally adjusted.`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Series">
      {#each Object.entries(SERIES) as [k, d]}<button class:on={sid === k} aria-pressed={sid === k} onclick={() => (sid = k as Sid)}>{d.label}</button>{/each}
    </div>
    <div class="seg" role="group" aria-label="How the test months are chosen">
      <button class:on={mode === 'random'} aria-pressed={mode === 'random'} onclick={() => (mode = 'random')}>Random split</button>
      <button class:on={mode === 'time'} aria-pressed={mode === 'time'} onclick={() => (mode = 'time')}>Split by time</button>
    </div>
    <button class="btn btn-sm" onclick={() => { seed += 1; mode = 'random'; }} aria-label="Draw a new random split">↻ Shuffle</button>
  {/snippet}
  {#snippet aside()}
    {#if res}
      <div class="ms" aria-live="polite">
        <div class="stat" class:dim={mode !== 'random'}><span class="stat-v">{fmt(res.random.mae)}</span><span class="stat-l"><b>Random split</b> MAE, {unit}</span></div>
        <div class="stat" class:dim={mode !== 'time'}><span class="stat-v">{fmt(res.time.mae)}</span><span class="stat-l"><b>Split by time</b> MAE, {unit}</span></div>
        <p class="note">The honest (time) error is <b>{isFinite(ratio) ? ratio.toFixed(1) : '—'}×</b> the random-split error.
          {#if mode === 'random'}Here {peeks === 24 ? 'every one' : peeks} of the 24 hidden months had a later known month to lean on.{:else}No hidden month can use a later month: the test set comes after the training set.{/if}</p>
        <div class="lg"><span><i class="k"></i>known (training)</span><span><i class="t"></i>hidden (test)</span><span><i class="f"></i>filled in</span></div>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 260px; }
  .ms { display: grid; gap: .8rem; font-size: .82rem; }
  .dim { opacity: .55; }
  .note { margin: 0; color: var(--text-2); line-height: 1.45; }
  .lg { display: flex; flex-wrap: wrap; gap: .4rem .9rem; font-size: .75rem; color: var(--text-2); }
  .lg span { display: inline-flex; align-items: center; gap: .35rem; }
  .lg i { width: 9px; height: 9px; border-radius: 50%; display: inline-block; }
  .lg i.k { background: var(--c-s1); width: 6px; height: 6px; }
  .lg i.t { border: 2px solid var(--c-actual); }
  .lg i.f { background: var(--c-forecast); }
</style>
