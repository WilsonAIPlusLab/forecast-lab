<script lang="ts">
  // "Does the seasonal swing grow with the level?" Measure each year's seasonal swing around a centered
  // 12-month moving average, in the data's units and in percent, and see which one stays steady.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, ym, type Series } from '../../lib/ts';
  import { C, watchLayout } from '../../lib/viz/theme';

  type Key = 'ecom' | 'house' | 'util';
  const SERIES: Record<Key, { id: string; name: string; unit: string; short: string; scale: number; fmtU: (v: number) => string }> = {
    ecom: { id: 'MRTSSM4541USN', name: 'E-commerce sales', unit: '$bn per month', short: 'e-commerce', scale: 1000, fmtU: (v) => `$${v.toFixed(1)}bn` },
    house: { id: 'HOUSTNSA', name: 'Housing starts', unit: 'thousand units per month', short: 'housing starts', scale: 1, fmtU: (v) => `${v.toFixed(0)}k` },
    util: { id: 'IPG2211A2N', name: 'Electric & gas utility output', unit: 'index, 2017 = 100', short: 'utility output', scale: 1, fmtU: (v) => `${v.toFixed(1)} pts` },
  };
  let key: Key = $state('ecom');
  let view: 'units' | 'pct' = $state('units');
  const cache: Partial<Record<Key, Series>> = {};
  let s: Series | null = $state(null);
  let el: HTMLDivElement;

  async function load(k: Key) {
    if (!cache[k]) cache[k] = await loadSeries(SERIES[k].id, { start: '2000-01-01', end: '2019-12-01' });
    if (k === key) s = cache[k]!;
  }
  $effect(() => { load(key); });

  const fit = $derived.by(() => {
    if (!s || s.id !== SERIES[key].id) return null;
    const meta = SERIES[key];
    const y = s.data.map((p) => p.value / meta.scale);
    const n = y.length;
    // centered 2x12 moving average: the same trend estimate R's decompose() uses
    const ma: (number | null)[] = y.map((_, i) => {
      if (i < 6 || i > n - 7) return null;
      let t = 0.5 * y[i - 6] + 0.5 * y[i + 6];
      for (let k = -5; k <= 5; k++) t += y[i + k];
      return t / 12;
    });
    const rows = s.data.map((p, i) => ({ date: p.date, yr: p.date.getFullYear(), y: y[i], ma: ma[i], du: ma[i] == null ? null : y[i] - (ma[i] as number), dp: ma[i] == null ? null : 100 * (y[i] / (ma[i] as number) - 1) }));
    const years = [...new Set(rows.map((r) => r.yr))];
    const sw = years.map((yr) => {
      const rr = rows.filter((r) => r.yr === yr);
      if (rr.length < 12 || rr.some((r) => r.ma == null)) return null;
      const du = rr.map((r) => r.du as number), dp = rr.map((r) => r.dp as number);
      return { yr, units: Math.max(...du) - Math.min(...du), pct: Math.max(...dp) - Math.min(...dp), level: rr.reduce((a, r) => a + (r.ma as number), 0) / 12 };
    }).filter(Boolean) as { yr: number; units: number; pct: number; level: number }[];
    const avg = (a: typeof sw, f: (x: (typeof sw)[0]) => number) => a.reduce((t, x) => t + f(x), 0) / a.length;
    const first = sw.slice(0, 3), last = sw.slice(-3);
    const A = { level: avg(first, (x) => x.level), units: avg(first, (x) => x.units), pct: avg(first, (x) => x.pct), label: `’${String(first[0].yr).slice(2)}–’${String(first[2].yr).slice(2)}` };
    const B = { level: avg(last, (x) => x.level), units: avg(last, (x) => x.units), pct: avg(last, (x) => x.pct), label: `’${String(last[0].yr).slice(2)}–’${String(last[2].yr).slice(2)}` };
    return { rows, sw, A, B, rL: B.level / A.level, rU: B.units / A.units, rP: B.pct / A.pct };
  });

  const verdict = $derived.by(() => {
    if (!fit) return '';
    const big = Math.abs(Math.log(fit.rL)) > Math.log(1.3);
    if (!big) return `The level hardly moved (×${fit.rL.toFixed(2)}), so the swing measured in units and in percent tell the same story. When the level is flat, additive and multiplicative models give nearly the same answer.`;
    if (Math.abs(Math.log(fit.rP)) < Math.abs(Math.log(fit.rU))) return `The level changed ×${fit.rL.toFixed(2)} and the swing in units changed ×${fit.rU.toFixed(2)} with it, while the swing in percent stayed steadier (×${fit.rP.toFixed(2)}). That is the signature of multiplicative seasonality: take logs.`;
    return `The swing in units stayed steadier than the swing in percent: this looks additive, so model the series in its own units.`;
  });

  const style = () => ({ background: 'transparent', color: C.muted, fontSize: '12px', fontFamily: 'var(--font-ui)', overflow: 'visible' as const });
  function draw() {
    if (!el || !fit) return;
    const W = el.clientWidth, meta = SERIES[key], rows = fit.rows, pct = view === 'pct';
    const common = { width: W, marginLeft: 58, marginRight: 14, style: style() };
    const p1 = Plot.plot({
      ...common, height: 210, marginTop: 16, marginBottom: 24, x: { label: null },
      y: { type: pct ? 'log' : 'linear', grid: true, ticks: 5, label: `${meta.unit}${pct ? ' (log scale)' : ''}`, tickFormat: (d: number) => `${+d.toPrecision(3)}` },
      marks: [
        Plot.lineY(rows, { x: 'date', y: 'y', stroke: C.history, strokeWidth: 1.8 }),
        Plot.lineY(rows.filter((r) => r.ma != null), { x: 'date', y: 'ma', stroke: C.fitted, strokeWidth: 2, strokeDasharray: '5 3' }),
        W >= 520 ? Plot.text([rows.filter((r) => r.ma != null).at(-1)!], { x: 'date', y: 'ma', text: () => 'trend (12-month average)', dy: -12, textAnchor: 'end', fill: C.fitted, fontWeight: 650, fontSize: 12 }) : null,
        Plot.tip(rows, Plot.pointerX({ x: 'date', y: 'y', title: (r: any) => `${ym(r.date)}\n${meta.name}: ${meta.fmtU(r.y)}${r.ma != null ? `\nTrend: ${meta.fmtU(r.ma)}\nGap: ${meta.fmtU(r.du)} = ${r.dp > 0 ? '+' : ''}${r.dp.toFixed(1)}%` : ''}` })),
      ].filter(Boolean) as any,
    });
    const p2 = Plot.plot({
      ...common, height: 150, marginTop: 18, marginBottom: 26, x: { label: null, tickFormat: (d: number) => (d % 4 === 0 ? String(d) : ''), tickSize: 0 },
      y: { grid: true, ticks: 4, label: pct ? 'seasonal swing, % of trend' : `seasonal swing, ${meta.unit.split(' per')[0].split(',')[0]}`, zero: true },
      marks: [
        Plot.barY(fit.sw, { x: 'yr', y: pct ? 'pct' : 'units', fill: pct ? C.s[2] : C.s[0], fillOpacity: 0.85 }),
        Plot.ruleY([0], { stroke: C.borderStrong }),
        Plot.tip(fit.sw, Plot.pointerX({ x: 'yr', y: pct ? 'pct' : 'units', title: (r: any) => `${r.yr}: peak-to-trough swing\n${meta.fmtU(r.units)} = ${r.pct.toFixed(1)}% of trend\nAverage trend level: ${meta.fmtU(r.level)}` })),
      ],
    });
    p1.setAttribute('aria-label', `${meta.name}, 2000 to 2019, with its 12-month moving-average trend${pct ? ', on a log scale' : ''}`);
    p2.setAttribute('aria-label', `Seasonal swing each year, measured ${pct ? 'in percent of the trend' : 'in the data units'}`);
    el.replaceChildren(p1, p2);
  }
  $effect(() => { fit; view; draw(); });
  onMount(() => watchLayout(el, draw));
</script>

<Explorable title="Does the swing grow with the level? Measure it twice" caption="Each bar is one year's <b>seasonal swing</b>: the highest month minus the lowest month, both measured against a centered 12-month moving average (the trend). Switch between measuring it in the data's own units and in percent of the trend. Whichever stays flatter is the right scale for your model. Data: FRED, NSA, 2000–2019 (before COVID).">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Series">
      {#each Object.entries(SERIES) as [k, m]}
        <button class:on={key === k} aria-pressed={key === k} onclick={() => (key = k as Key)}>{m.name}</button>
      {/each}
    </div>
    <div class="seg" role="group" aria-label="Measure the swing in">
      <button class:on={view === 'units'} aria-pressed={view === 'units'} onclick={() => (view = 'units')}>Swing in units</button>
      <button class:on={view === 'pct'} aria-pressed={view === 'pct'} onclick={() => (view = 'pct')}>Swing in % (log scale)</button>
    </div>
  {/snippet}
  {#snippet aside()}
    {#if fit}
      <div class="ro">
        <table class="cmp">
          <thead><tr><th></th><th>{fit.A.label}</th><th>{fit.B.label}</th><th>change</th></tr></thead>
          <tbody>
            <tr><td>Trend level</td><td>{SERIES[key].fmtU(fit.A.level)}</td><td>{SERIES[key].fmtU(fit.B.level)}</td><td>×{fit.rL.toFixed(2)}</td></tr>
            <tr class:hi={view === 'units'}><td>Swing in units</td><td>{SERIES[key].fmtU(fit.A.units)}</td><td>{SERIES[key].fmtU(fit.B.units)}</td><td>×{fit.rU.toFixed(2)}</td></tr>
            <tr class:hi={view === 'pct'}><td>Swing in %</td><td>{fit.A.pct.toFixed(0)}%</td><td>{fit.B.pct.toFixed(0)}%</td><td>×{fit.rP.toFixed(2)}</td></tr>
          </tbody>
        </table>
        <p class="note">{verdict}</p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart" aria-label="Series with trend, and the yearly seasonal swing"></div>
</Explorable>

<style>
  .chart { min-height: 360px; }
  .ro { display: grid; gap: .8rem; font-size: .82rem; }
  .cmp { width: 100%; border-collapse: collapse; font-variant-numeric: tabular-nums; margin: 0 !important; font-size: .8rem !important; }
  .cmp th { font-weight: 600; color: var(--muted); text-align: right; padding: .2rem .3rem; }
  .cmp td { text-align: right; padding: .25rem .3rem; border-top: 1px solid var(--border); color: var(--text-2); }
  .cmp td:first-child { text-align: left; color: var(--text); }
  .cmp tr.hi td { background: color-mix(in srgb, var(--accent) 12%, transparent); color: var(--text); font-weight: 650; }
  .note { margin: 0; color: var(--text-2); line-height: 1.5; border-top: 1px solid var(--border); padding-top: .7rem; }
</style>
