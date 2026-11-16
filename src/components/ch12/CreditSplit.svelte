<script lang="ts">
  // Explorable: correlated features split SHAP credit unpredictably; read their sum, not the split.
  // Data: precomputed natively in R by src/labs/ch12/make_data.R. Refits A-D use the tuned settings plus
  // colsample_bytree = 0.5 (each tree may use a random half of the features) with four different seeds.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import data from './interpret_data.json';

  type V = { name: string; mae: number; month: number[]; ly: number[]; other: number[]; base: number[]; fc: number[] };
  const D = data.credit;
  const V = D.variants as V[];
  const dates: string[] = D.dates;
  const MON = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  const label = (s: string) => `${MON[+s.slice(5, 7) - 1]} ${s.slice(0, 4)}`;
  const money = (v: number) => `${v < 0 ? '−' : '+'}$${Math.abs(v).toFixed(1)}bn`;
  const PARTS = [
    { k: 'month', name: 'Calendar month', col: () => C.s[2] },
    { k: 'ly', name: 'Same month last year’s growth', col: () => C.s[4] },
    { k: 'other', name: 'Everything else', col: () => C.muted },
  ] as const;
  const iJan = dates.indexOf('2024-01-01'), iDec = dates.indexOf('2025-12-01');
  let idx = $state(iJan);
  let el: HTMLDivElement;

  const refits = V.slice(0, 5);                                  // tuned model + refits A-D (all seven features)
  const span = (a: number[]) => [Math.min(...a), Math.max(...a)] as const;
  const stats = $derived.by(() => {
    const i = idx;
    const mo = span(refits.map((v) => v.month[i])), ly = span(refits.map((v) => v.ly[i]));
    const sum = span(refits.map((v) => v.month[i] + v.ly[i])), fc = span(refits.map((v) => v.fc[i]));
    return { mo, ly, sum, fc };
  });

  function draw() {
    if (!el) return;
    const W = el.clientWidth, i = idx;
    const segs = V.flatMap((v) => PARTS.map((p) => ({ name: v.name, part: p.name, col: p.col(), v: (v as any)[p.k][i] as number })));
    const sums = V.map((v) => ({ name: v.name, s: v.month[i] + v.ly[i], fc: v.fc[i], mae: v.mae }));
    const lo = Math.min(0, ...V.map((v) => Math.min(v.month[i], 0) + Math.min(v.ly[i], 0) + Math.min(v.other[i], 0)));
    const hi = Math.max(0, ...V.map((v) => Math.max(v.month[i], 0) + Math.max(v.ly[i], 0) + Math.max(v.other[i], 0)));
    const pad = Math.max(8, (hi - lo) * 0.06);
    const narrow = W < 520;
    el.replaceChildren(Plot.plot({
      width: W, height: 60 + V.length * 40, marginLeft: narrow ? 128 : 170, marginRight: narrow ? 64 : 92, marginTop: 26, marginBottom: 40,
      style: plotStyle(),
      ariaLabel: `SHAP credit for ${label(dates[i])} in six refits. Calendar month ranges from ${money(stats.mo[0])} to ${money(stats.mo[1])}; last year's growth from ${money(stats.ly[0])} to ${money(stats.ly[1])}; their sum only from ${money(stats.sum[0])} to ${money(stats.sum[1])}.`,
      x: { label: 'SHAP push on the forecast, $ billions', grid: true, domain: [lo - pad, hi + pad], tickFormat: (v: number) => (v === 0 ? '0' : `${v > 0 ? '+' : '−'}${Math.abs(v)}`) },
      y: { domain: V.map((v) => v.name), label: null, tickSize: 0, tickFormat: (s: string) => (narrow ? s.replace(' (Lab 12.2)', '').replace('Without calendar month', 'No calendar month') : s) },
      marks: [
        Plot.ruleY([V[4].name], { stroke: C.border, dy: 20 }),
        Plot.ruleX([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
        Plot.barX(segs, Plot.stackX({ y: 'name', x: 'v', fill: 'col', order: PARTS.map((p) => p.name), z: 'part', insetTop: 9, insetBottom: 9, title: (s: any) => `${s.name}\n${s.part}: ${money(s.v)}` })),
        Plot.tickX(sums, { y: 'name', x: 's', stroke: C.text, strokeWidth: 2.5, insetTop: 4, insetBottom: 4 }),
        Plot.text([0], { frameAnchor: 'top-right', dx: narrow ? 60 : 88, dy: -20, textAnchor: 'end', text: () => 'Forecast', fill: C.muted, fontSize: 12 }),
        Plot.text(sums, { y: 'name', frameAnchor: 'right', dx: narrow ? 60 : 88, textAnchor: 'end', text: (s: any) => `$${s.fc.toFixed(1)}bn`, fill: C.forecast, fontSize: 12, fontWeight: 600 }),
        Plot.tip(sums, Plot.pointer({ y: 'name', x: 's', title: (s: any) => `${s.name}\nSeasonal pair (month + last year): ${money(s.s)}\nForecast: $${s.fc.toFixed(1)}bn\nTest MAE, 2023–2026: $${s.mae.toFixed(2)}bn` })),
      ],
    }));
  }
  onMount(() => watchLayout(el, draw));
  $effect(() => { idx; draw(); });
</script>

<Explorable title="Refit the model and the credit for seasonality jumps between two features; their sum barely moves" caption={`Each row is one XGBoost model explaining the same forecast. Refits A to D use the tuned settings, but each tree may split on only a random half of the features (<code>colsample_bytree = 0.5</code>, a common XGBoost setting), with four different random seeds. Bars: <span style="color:var(--c-s3);font-weight:650">calendar month</span>, <span style="color:var(--c-s5);font-weight:650">same month last year's growth</span> and everything else; the tick marks the sum of the two seasonal features; violet on the right is each model's forecast. Out-of-sample months, models trained 1993 to 2022. Data: FRED RSXFSN (NSA), UMCSENT, UNRATE; $ billions.`}>
  {#snippet controls()}
    <label class="sl">Month <input type="range" min="0" max={dates.length - 1} bind:value={idx} aria-label="Forecast month" aria-valuetext={label(dates[idx])} /> <b>{label(dates[idx]).slice(0, 3)} {dates[idx].slice(0, 4)}</b></label>
    <span class="seg" role="group" aria-label="Jump to a month">
      <button class:on={idx === iJan} aria-pressed={idx === iJan} onclick={() => (idx = iJan)}>January 2024</button>
      <button class:on={idx === iDec} aria-pressed={idx === iDec} onclick={() => (idx = iDec)}>December 2025</button>
    </span>
  {/snippet}
  {#snippet aside()}
    <div class="side" aria-live="polite">
      <div class="eyebrow">{label(dates[idx])}: range over the five refits</div>
      <dl class="rg">
        <div><dt>Calendar month</dt><dd>{money(stats.mo[0])} to {money(stats.mo[1])}</dd><dd class="w">{(stats.mo[1] - stats.mo[0]).toFixed(1)}</dd></div>
        <div><dt>Last year’s growth</dt><dd>{money(stats.ly[0])} to {money(stats.ly[1])}</dd><dd class="w">{(stats.ly[1] - stats.ly[0]).toFixed(1)}</dd></div>
        <div class="sum"><dt>The two together</dt><dd>{money(stats.sum[0])} to {money(stats.sum[1])}</dd><dd class="w">{(stats.sum[1] - stats.sum[0]).toFixed(1)}</dd></div>
        <div><dt>Forecast</dt><dd>${stats.fc[0].toFixed(1)} to {stats.fc[1].toFixed(1)}bn</dd><dd class="w">{(stats.fc[1] - stats.fc[0]).toFixed(1)}</dd></div>
      </dl>
      <p class="note">Last column: the spread in $bn. The split between the two seasonal features is not a fact about the economy; it depends on which trees happened to grow. <b>Without calendar month</b>, last year’s growth takes over much of the seasonal credit, and test MAE rises from ${V[0].mae.toFixed(2)}bn to ${V[5].mae.toFixed(2)}bn.</p>
    </div>
  {/snippet}
  <div class="key" aria-hidden="true">
    <span><i style="background:var(--c-s3)"></i>Calendar month</span>
    <span><i style="background:var(--c-s5)"></i>Same month last year’s growth</span>
    <span><i style="background:var(--muted)"></i>Everything else</span>
    <span><i class="tk"></i>Sum of the two seasonal features</span>
  </div>
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 300px; }
  .key { display: flex; flex-wrap: wrap; gap: .3rem 1rem; font-size: .78rem; color: var(--text-2); margin-bottom: .3rem; }
  .key span { display: inline-flex; align-items: center; gap: .35rem; }
  .key i { width: 11px; height: 11px; border-radius: 2px; display: inline-block; }
  .key i.tk { width: 3px; height: 14px; border-radius: 0; background: var(--text); }
  .side { font-size: .82rem; color: var(--text-2); }
  .eyebrow { font-size: .8rem; font-weight: 650; color: var(--muted); margin-bottom: .35rem; }
  .rg { margin: 0 0 .6rem; }
  .rg div { display: grid; grid-template-columns: 1fr auto 2.6rem; gap: .5rem; padding: .22rem 0; border-bottom: 1px dotted var(--border); align-items: baseline; }
  .rg dt { font-size: .78rem; }
  .rg dd { margin: 0; font-variant-numeric: tabular-nums; color: var(--text); font-size: .76rem; white-space: nowrap; }
  .rg dd.w { text-align: right; font-weight: 650; }
  .rg .sum dt, .rg .sum dd { font-weight: 700; }
  .note { margin: 0; line-height: 1.5; font-size: .78rem; }
  .note b { color: var(--text); }
</style>
