<script lang="ts">
  // Reading a nowcast revision: when next Thursday's claims print arrives, how much should the payroll nowcast move, and why?
  // Same bridge regressions as the ragged-edge explorable: one regression per number of weeks known.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { ols, ymKey, monthName, dayFmt } from './lib';

  let ready = $state(false);
  let next = $state(200); // next week's initial claims, thousands
  let el: HTMLDivElement;
  let weeks = new Map<string, { date: Date; v: number }[]>();
  let fullAvg = new Map<string, number>();
  let dp = new Map<string, number>();
  let lastWeek: Date = new Date();
  let wkChangeSd = $state(0);
  const prevKey = (k: string) => { const [y, m] = k.split('-').map(Number); return ymKey(new Date(y, m - 2, 1)); };

  onMount(() => {
    Promise.all([loadSeries('ICSA'), loadSeries('PAYEMS')]).then(([ic, pay]) => {
      for (const p of ic.data) { const k = ymKey(p.date); (weeks.get(k) || weeks.set(k, []).get(k)!).push({ date: p.date, v: p.value / 1000 }); }
      for (const [k, w] of weeks) fullAvg.set(k, w.reduce((s, x) => s + x.v, 0) / w.length);
      for (let i = 1; i < pay.data.length; i++) dp.set(ymKey(pay.data[i].date), pay.data[i].value - pay.data[i - 1].value);
      lastWeek = ic.data[ic.data.length - 1].date;
      // typical week-to-week change in claims over the last three years (156 weeks)
      const r = ic.data.slice(-157).map((p) => p.value / 1000);
      const d = r.slice(1).map((v, i) => v - r[i]);
      const m = d.reduce((s, v) => s + v, 0) / d.length;
      wkChangeSd = Math.sqrt(d.reduce((s, v) => s + (v - m) ** 2, 0) / (d.length - 1));
      next = Math.round(weeks.get(ymKey(lastWeek))!.slice(-1)[0].v);
      ready = true;
    });
    return watchLayout(el, draw);
  });

  // Bridge regressions for the live month with k and k+1 weeks of claims.
  const model = $derived.by(() => {
    if (!ready) return null;
    const target = ymKey(lastWeek);
    const known = weeks.get(target)!;
    const k = known.length;
    const train = [...dp.keys()].filter((t) => t >= '1990-01' && t < target && !t.startsWith('2020') && !t.startsWith('2021') && dp.has(prevKey(t)) && fullAvg.has(prevKey(t)) && weeks.has(t));
    const fitK = (kk: number) => ols(train.map((t) => { const w = weeks.get(t)!; const part = w.slice(0, Math.min(kk, w.length)); return [dp.get(prevKey(t))!, part.reduce((s, x) => s + x.v, 0) / part.length - fullAvg.get(prevKey(t))!]; }), train.map((t) => dp.get(t)!));
    const f0 = fitK(k), f1 = fitK(k + 1);
    const lag = dp.get(prevKey(target))!, prevFull = fullAvg.get(prevKey(target))!;
    const sumK = known.reduce((s, x) => s + x.v, 0);
    const before = f0.predict([lag, sumK / k - prevFull]);
    const lastV = known[k - 1].v;
    const noNews = f1.predict([lag, (sumK + lastV) / (k + 1) - prevFull]);
    const nextEnd = new Date(+lastWeek + 7 * 864e5);
    const nextRel = new Date(+nextEnd + 5 * 864e5);
    return { target, k, f0, f1, lag, prevFull, sumK, before, lastV, noNews, beta: f1.beta[2], nextEnd, nextRel, lastWeek };
  });
  const after = $derived(model ? model.f1.predict([model.lag, (model.sumK + next) / (model.k + 1) - model.prevFull]) : 0);
  const news = $derived(model ? after - model.noNews : 0);
  const surprise = $derived(model ? next - model.lastV : 0);
  const k0 = (v: number) => `${v >= 0 ? '+' : '−'}${Math.abs(Math.round(v)).toLocaleString('en-US')}k`;

  function draw() {
    if (!el || !model) return;
    const W = el.clientWidth, narrow = W < 560;
    if (W < 200) return; // not laid out yet; watchLayout redraws once it has a real width
    const b0 = 1.645 * model.f0.sigma, b1 = 1.645 * model.f1.sigma;
    const steps = [
      { k: narrow ? 'Before' : `Before (${model.k} wk)`, lo: 0, hi: model.before, kind: 'level', band: b0 },
      { k: narrow ? 'Update' : 'Model update', lo: model.before, hi: model.noNews, kind: 'delta' },
      { k: 'News', lo: model.noNews, hi: after, kind: 'news' },
      { k: narrow ? 'After' : `After (${model.k + 1} wk)`, lo: 0, hi: after, kind: 'level', band: b1 },
    ];
    const lvl = steps.filter((s) => s.kind === 'level');
    const ys = [0, ...lvl.flatMap((s) => [s.hi - s.band!, s.hi + s.band!])];
    const fill = (s: any) => (s.kind === 'level' ? C.forecast : s.kind === 'news' ? (s.hi < s.lo ? C.s[1] : C.s[0]) : C.muted);
    const chart = Plot.plot({
      width: W, height: 320, marginLeft: 56, marginRight: 12, marginTop: 24, marginBottom: 34, style: plotStyle(),
      x: { domain: steps.map((s) => s.k), label: null, padding: 0.35, tickSize: 0 },
      y: { grid: true, label: '↑ Nowcast of the payroll change (thousands of jobs)', domain: [Math.min(...ys) - 20, Math.max(...ys) + 20] },
      marks: [
        Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
        Plot.barY(steps, { x: 'k', y1: 'lo', y2: 'hi', fill, fillOpacity: (s: any) => (s.kind === 'level' ? 0.85 : 0.9), rx: 3 }),
        // 90% prediction band around the two nowcasts
        Plot.ruleX(lvl, { x: 'k', y1: (s: any) => s.hi - s.band, y2: (s: any) => s.hi + s.band, stroke: C.text2, strokeWidth: 1.5, dx: 0 }),
        Plot.tickY(lvl.flatMap((s) => [{ k: s.k, y: s.hi - s.band! }, { k: s.k, y: s.hi + s.band! }]), { x: 'k', y: 'y', stroke: C.text2, strokeWidth: 1.5 }),
        Plot.text(steps, { x: 'k', y: (s: any) => (s.kind === 'level' ? s.hi : Math.max(s.lo, s.hi)), text: (s: any) => (s.kind === 'level' ? k0(s.hi) : k0(s.hi - s.lo)), dy: -10, fill: C.text, fontWeight: 650, fontSize: 12, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' } as any),
        Plot.text(lvl.slice(0, 1), { x: 'k', y: (s: any) => s.hi + s.band, text: () => '90% band', dy: -8, fill: C.muted, fontSize: 12 }),
      ],
    });
    chart.setAttribute('aria-label', `Waterfall: the nowcast for ${monthName(new Date(model.target + '-01T00:00:00'), true)} moves from ${k0(model.before)} to ${k0(after)} jobs after a claims print of ${next} thousand. The news part is ${k0(news)}.`);
    el.replaceChildren(chart);
  }
  $effect(() => { next; model; draw(); });
</script>

<Explorable title="One Thursday's news, in jobs: how a nowcast revision works" caption={`The bridge nowcast of this month's payroll change, before and after next Thursday's jobless-claims print. Drag the slider to choose what that print will be. The <b>model update</b> is the small shift from switching to the regression built for one more week of claims; the <b>news</b> is what the new number itself adds. Whiskers show the 90% prediction band. Same bridge regressions as the ragged-edge explorable above (1990 onward, excluding 2020–21). Data: FRED (ICSA, PAYEMS), SA.`}>
  {#snippet controls()}
    {#if model}
      <label class="sl">Claims, week ending {dayFmt(model.nextEnd)} <input type="range" min="150" max="450" step="5" bind:value={next} aria-label="Next week's initial claims, thousands" /> <b>{next}k</b></label>
      <button class="btn btn-sm" onclick={() => (next = Math.round(model!.lastV))}>No surprise ({Math.round(model.lastV)}k)</button>
    {/if}
  {/snippet}
  {#snippet aside()}
    {#if model}
      <div class="side" aria-live="polite">
        <div class="eyebrow">Read the revision in words</div>
        {#if Math.abs(surprise) < 0.5}
          <p class="words">Claims come in at <b>{next}k</b>, the same as last week. <b>No news</b>: the nowcast moves only by the small model update ({k0(model.noNews - model.before)}). Drag the slider to add a surprise.
            Each extra 1,000 in the monthly average goes with about <b>{(Math.round(Math.abs(model.beta) * 100) * 10).toLocaleString('en-US')}</b> fewer jobs.</p>
        {:else}
          <p class="words">Claims come in at <b>{next}k</b>, {Math.abs(Math.round(surprise))}k {surprise > 0 ? 'above' : 'below'} last week's {Math.round(model.lastV)}k.
            With {model.k + 1} weeks known, that {surprise > 0 ? 'raises' : 'lowers'} this month's average by <b>{(Math.abs(surprise) / (model.k + 1)).toFixed(1)}k</b> a week.
            Each extra 1,000 in the monthly average goes with about <b>{(Math.round(Math.abs(model.beta) * 100) * 10).toLocaleString('en-US')}</b> fewer jobs, so the news moves the nowcast by <b>{k0(news)}</b>.</p>
        {/if}
        <div class="kp"><span class="v">{k0(after)}</span><span class="l">new nowcast, published {dayFmt(model.nextRel)} (was {k0(model.before)})</span></div>
        <div class="kp"><span class="v">±{(wkChangeSd).toFixed(0)}k</span><span class="l">typical week-to-week change in claims (last 3 years), worth about ±{Math.abs(model.beta * wkChangeSd / (model.k + 1)).toFixed(0)}k jobs here</span></div>
        <p class="note">Compare that with the 90% band of about ±{(1.645 * model.f1.sigma).toFixed(0)}k. A normal week barely moves the nowcast; only a big surprise does.</p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart"></div>
  {#if !ready}<p class="load">Loading…</p>{/if}
</Explorable>

<style>
  .chart { min-height: 320px; }
  .side { font-size: .82rem; }
  .words { color: var(--text-2); margin: .3rem 0 .4rem; line-height: 1.5; }
  .kp { display: flex; flex-direction: column; margin: .45rem 0; }
  .kp .v { font: 700 1.35rem/1.1 var(--font-ui); color: var(--text); font-variant-numeric: tabular-nums; }
  .kp .l { color: var(--muted); font-size: .76rem; }
  .note { color: var(--text-2); margin: .3rem 0 0; }
  .load { color: var(--muted); }
</style>
