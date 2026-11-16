<script lang="ts">
  // Explorable: what the choice of target (growth vs level) does to the forecast and to the units of its SHAP receipt.
  // Data: precomputed natively in R by src/labs/ch12/make_data.R (growth model = Lab 12.3's tuned model;
  // levels model = same settings, target = sales in $ billions, 143 trees chosen by early stopping on 2022).
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import data from './interpret_data.json';

  type M = { date: string; actual: number; lag1: number; sales_ly: number; g_fc: number; g_base: number; g_shap: number[]; g_x: (number | null)[]; l_fc: number; l_base: number; l_shap: number[] };
  const L = data.levels;
  const months = L.months as M[];
  const GF: string[] = L.growth_features, LF: string[] = L.level_features;
  const NAMES: Record<string, string> = {
    month: 'Calendar month', growth_ly: 'Same month last year’s growth', growth_lm: 'Last month’s growth', yoy_lm: 'Last month’s 12-month growth',
    weekend: 'Weekend days', sent_lm: 'Consumer sentiment', unrate_lm: 'Unemployment rate', lag1: 'Last month’s sales (level)', sales_ly: 'Same month last year’s sales (level)',
  };
  const MON = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  const label = (s: string) => `${MON[+s.slice(5, 7) - 1]} ${s.slice(0, 4)}`;
  const money = (v: number) => `${v < 0 ? '−' : '+'}$${Math.abs(v).toFixed(1)}bn`;
  const mae = (k: 'g_fc' | 'l_fc') => months.reduce((s, m) => s + Math.abs(m.actual - m[k]), 0) / months.length;
  const MAE = { growth: mae('g_fc'), level: mae('l_fc') };
  const above = months.filter((m) => m.actual > L.train_max).length;
  const levMax = Math.max(...months.map((m) => m.l_fc));

  let target: 'growth' | 'level' = $state('growth');
  let idx = $state(months.findIndex((m) => m.date === '2025-12-01'));
  let el: HTMLDivElement;
  const cur = $derived(months[idx]);

  // the SHAP receipt: start, base value, the three largest pushes, everything else, forecast ($ billions)
  const receipt = $derived.by(() => {
    const m = cur, g = target === 'growth';
    const F = g ? GF : LF, S = g ? m.g_shap : m.l_shap;
    const items = F.map((f, j) => ({ f, v: S[j] })).sort((a, b) => Math.abs(b.v) - Math.abs(a.v));
    const top = items.slice(0, 3), rest = items.slice(3).reduce((s, it) => s + it.v, 0);
    return { start: g ? m.lag1 : 0, base: g ? m.g_base : m.l_base, top, rest, fc: g ? m.g_fc : m.l_fc };
  });
  const sentence = $derived.by(() => {
    const t = receipt.top[0], m = cur, mo = MON[+m.date.slice(5, 7) - 1];
    if (target === 'growth') {
      if (t.f === 'growth_ly') return `“A year ago, ${mo} sales grew ${(m.g_x[1] as number).toFixed(1)}% over the month before. The model expects a similar move, worth ${money(t.v)}.” That is news a manager can use.`;
      return `“${NAMES[t.f]} moves this forecast by ${money(t.v)}.” Every push is a change from last month’s sales, so each one is news about <i>this</i> month.`;
    }
    if (t.f === 'sales_ly' || t.f === 'lag1') return `“${NAMES[t.f]} pushes the forecast up by ${money(t.v)}.” True, but all it says is that sales today are far above the 1993–2022 average of $${L.train_mean.toFixed(1)}bn. No manager learns anything from it.`;
    return `“${NAMES[t.f]} moves the forecast by ${money(t.v)}” — measured from the 1993–2022 average month, not from last month.`;
  });

  function draw() {
    if (!el) return;
    const W = el.clientWidth;
    const pts = months.map((m) => ({ d: new Date(m.date + 'T00:00:00'), a: m.actual, g: m.g_fc, l: m.l_fc }));
    const key = target === 'growth' ? 'g' : 'l', other = target === 'growth' ? 'l' : 'g';
    const sel = pts[idx];
    el.replaceChildren(Plot.plot({
      width: W, height: Math.max(250, Math.min(330, W * 0.42)), marginLeft: 50, marginRight: 14, marginTop: 36, marginBottom: 30,
      style: plotStyle(),
      ariaLabel: `Actual retail sales and one-month-ahead forecasts, January 2023 to September 2026. Showing the ${target === 'growth' ? 'growth' : 'levels'} model. The levels model never forecasts above $${L.train_max.toFixed(0)} billion.`,
      x: { label: null },
      y: { label: '$bn', grid: true, domain: [490, 710], tickFormat: (v: number) => `$${v}` },
      marks: [
        Plot.ruleY([L.train_max], { stroke: C.s[1], strokeDasharray: '5,4', strokeWidth: 1.5 }),
        // label sits in the top margin, clear of the lines: the dashed red rule is the training record
        Plot.text([0], { frameAnchor: 'top-right', dy: -24, textAnchor: 'end', fill: C.s[1], fontSize: 12, fontWeight: 600,
          text: () => `Red dashes = training record, $${L.train_max.toFixed(1)}bn${W < 520 ? '' : ' (Dec 2022)'}` }),
        Plot.lineY(pts, { x: 'd', y: other, stroke: C.forecast, strokeWidth: 1.25, strokeOpacity: 0.35, strokeDasharray: '3,3' }),
        Plot.lineY(pts, { x: 'd', y: 'a', stroke: C.actual, strokeWidth: 2 }),
        Plot.lineY(pts, { x: 'd', y: key, stroke: C.forecast, strokeWidth: 2.5 }),
        Plot.ruleX([sel.d], { stroke: C.text, strokeOpacity: 0.35 }),
        Plot.dot([sel], { x: 'd', y: 'a', r: 4.5, fill: C.actual }),
        Plot.dot([sel], { x: 'd', y: key, r: 4.5, fill: C.forecast, stroke: C.surface, strokeWidth: 1.2 }),
        Plot.tip(pts, Plot.pointerX({ x: 'd', y: key, title: (p: any) => `${p.d.toLocaleString('en-US', { month: 'short', year: 'numeric' })}\nActual: $${p.a.toFixed(1)}bn\nGrowth model: $${p.g.toFixed(1)}bn\nLevels model: $${p.l.toFixed(1)}bn` })),
      ],
    }));
  }
  onMount(() => watchLayout(el, draw));
  $effect(() => { target; idx; draw(); });
</script>

<Explorable title="Predict growth, not levels: a levels model cannot forecast a record, and its SHAP receipt says nothing new" caption={`Two XGBoost models with the same settings and the same test months. <b>Growth</b> (Lab 12.3's model) predicts this month's % change and converts it to dollars with last month's sales. <b>Level</b> predicts sales in $ billions directly from last month's and last year's sales, the calendar and the macro features. <span style="color:var(--c-actual);font-weight:650">Gold</span> = actual, <span style="color:var(--c-forecast);font-weight:650">violet</span> = the selected model's one-month-ahead forecast (dashed = the other model). The SHAP receipt is the breakdown of the chosen month, in $ billions. Data: FRED RSXFSN (NSA), UMCSENT, UNRATE.`}>
  {#snippet controls()}
    <span class="grp"><span class="lab" id="lg-t">Target</span>
      <span class="seg" role="group" aria-labelledby="lg-t">
        <button class:on={target === 'growth'} aria-pressed={target === 'growth'} onclick={() => (target = 'growth')}>Growth, then $</button>
        <button class:on={target === 'level'} aria-pressed={target === 'level'} onclick={() => (target = 'level')}>Level in $</button>
      </span></span>
    <label class="sl">Month <input type="range" min="0" max={months.length - 1} bind:value={idx} aria-label="Month to explain" aria-valuetext={label(cur.date)} /> <b>{label(cur.date).slice(0, 3)} {cur.date.slice(0, 4)}</b></label>
  {/snippet}
  {#snippet aside()}
    <div class="side" aria-live="polite">
      <div class="eyebrow">SHAP receipt, {label(cur.date)}</div>
      <dl class="rc">
        {#if target === 'growth'}<div><dt>Last month’s sales</dt><dd>${receipt.start.toFixed(1)}bn</dd></div>{/if}
        <div><dt>Base value {target === 'growth' ? '(an average month’s growth)' : '(the average month, 1993–2022)'}</dt><dd>{target === 'growth' ? money(receipt.base) : `$${receipt.base.toFixed(1)}bn`}</dd></div>
        {#each receipt.top as t}<div><dt>{NAMES[t.f]}</dt><dd class:up={t.v >= 0} class:down={t.v < 0}>{money(t.v)}</dd></div>{/each}
        <div><dt>Everything else</dt><dd>{money(receipt.rest)}</dd></div>
        <div class="tot"><dt>Forecast</dt><dd>${receipt.fc.toFixed(1)}bn</dd></div>
        <div class="act"><dt>Actual</dt><dd>${cur.actual.toFixed(1)}bn</dd></div>
      </dl>
      <p class="say">{@html sentence}</p>
      <p class="score">Test MAE, Jan 2023 to Sep 2026: growth <b>${MAE.growth.toFixed(2)}bn</b>, level <b>${MAE.level.toFixed(2)}bn</b>. Actual sales topped the training record in <b>{above}</b> of {months.length} months; the levels model’s highest forecast is <b>${levMax.toFixed(1)}bn</b>.</p>
    </div>
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 250px; }
  .grp { display: inline-flex; align-items: center; gap: .5rem; flex-wrap: wrap; }
  .lab { font-size: .82rem; }
  .side { font-size: .82rem; color: var(--text-2); }
  .eyebrow { font-size: .8rem; font-weight: 650; color: var(--muted); margin-bottom: .35rem; }
  .rc { margin: 0 0 .6rem; font-family: var(--font-mono); font-size: .76rem; }
  .rc div { display: flex; justify-content: space-between; gap: .6rem; padding: .18rem 0; border-bottom: 1px dotted var(--border); }
  .rc dt { font-family: var(--font-ui); font-size: .78rem; color: var(--text-2); }
  .rc dd { margin: 0; font-variant-numeric: tabular-nums; color: var(--text); white-space: nowrap; font-weight: 600; }
  .rc dd.up { color: var(--c-s2); } .rc dd.down { color: var(--c-s1); }
  .rc .tot { border-top: 1.5px solid var(--border-strong); border-bottom: none; margin-top: .15rem; }
  .rc .tot dd { color: var(--c-forecast); }
  .rc .act dd { color: var(--c-actual); }
  .say { margin: 0 0 .6rem; line-height: 1.5; }
  .score { margin: 0; color: var(--muted); font-size: .78rem; line-height: 1.45; }
  .score b { color: var(--text); font-variant-numeric: tabular-nums; }
</style>
