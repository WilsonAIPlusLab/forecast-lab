<script lang="ts">
  // Additive vs multiplicative classical decomposition of NSA e-commerce sales, whose seasonal swings grow with the level.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, ym, type Series } from '../../lib/ts';
  import { C, watchLayout } from '../../lib/viz/theme';
  import { classical, acfAt } from './stl';

  let type: 'additive' | 'multiplicative' = $state('additive');
  let s: Series | null = $state(null);
  let el: HTMLDivElement;
  onMount(async () => { s = await loadSeries('MRTSSM4541USN', { start: '2000-01-01', end: '2019-12-01' }); });

  const fit = $derived.by(() => {
    if (!s) return null;
    const x = s.data.map((p) => p.value);
    const c = classical(x, 12, type, s.data[0].date.getMonth());
    const add = type === 'additive';
    const rows = s.data.map((p, i) => {
      const t = c.trend[i], r = c.remainder[i];
      return { date: p.date, m: p.date.getMonth(), y: p.value / 1000, fit: t == null ? null : (add ? t + c.seasonal[i] : t * c.seasonal[i]) / 1000, r: r == null ? null : add ? r / 1000 : 100 * (r - 1) };
    });
    const rem = rows.filter((r) => r.r != null).map((r) => r.r as number);
    const decRow = (yy: number) => rows.find((r) => r.m === 11 && r.date.getFullYear() === yy)!;
    const tr = (yy: number) => c.trend[rows.indexOf(decRow(yy))] as number;
    const decEff = (yy: number) => (add ? c.figure[11] : tr(yy) * (c.figure[11] - 1)) / 1000;
    return { rows, acf12: acfAt(rem, 12), fig: c.figure[11], d2000: decEff(2000), d2018: decEff(2018) };
  });

  const style = () => ({ background: 'transparent', color: C.muted, fontSize: '12px', fontFamily: 'var(--font-ui)', overflow: 'visible' as const });
  function draw() {
    if (!el || !fit) return;
    const W = el.clientWidth, rows = fit.rows, add = type === 'additive';
    const common = { width: W, marginLeft: 58, marginRight: W < 560 ? 12 : 120, style: style() };
    const p1 = Plot.plot({
      ...common, height: 230, marginTop: 14, marginBottom: 6, x: { axis: null }, y: { grid: true, ticks: 5, label: '$bn per month', tickFormat: (d: number) => `$${d}` },
      marks: [
        Plot.lineY(rows, { x: 'date', y: 'y', stroke: C.history, strokeWidth: 2 }),
        Plot.lineY(rows.filter((r) => r.fit != null), { x: 'date', y: 'fit', stroke: C.fitted, strokeWidth: 1.5, strokeDasharray: '4 3' }),
        W >= 560 ? Plot.text([rows[rows.length - 1]], { x: 'date', y: 'y', text: () => 'actual', dx: 8, textAnchor: 'start', fill: C.history, fontWeight: 650, fontSize: 12 }) : null,
        W >= 560 ? Plot.text([rows.filter((r) => r.fit != null).at(-1)!], { x: 'date', y: 'fit', text: () => (add ? 'trend + seasonal' : 'trend × seasonal'), dx: 8, dy: 14, textAnchor: 'start', fill: C.fitted, fontWeight: 650, fontSize: 12 }) : null,
        Plot.tip(rows, Plot.pointerX({ x: 'date', y: 'y', title: (r: any) => `${ym(r.date)}\nActual: $${r.y.toFixed(1)}bn${r.fit != null ? `\nModel: $${r.fit.toFixed(1)}bn` : ''}` })),
      ].filter(Boolean) as any,
    });
    const rr = rows.filter((r) => r.r != null);
    const p2 = Plot.plot({
      ...common, height: 170, marginTop: 16, marginBottom: 28, x: { label: null }, y: { grid: true, ticks: 4, label: add ? 'remainder, $bn' : 'remainder, %', tickFormat: (d: number) => `${d > 0 ? '+' : d < 0 ? '−' : ''}${add ? '$' : ''}${Math.abs(d)}${add ? '' : '%'}` },
      marks: [
        Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
        Plot.ruleX(rr, { x: 'date', y1: 0, y2: 'r', stroke: (r: any) => (r.m === 11 ? C.actual : C.s[1]), strokeWidth: (r: any) => (r.m === 11 ? 3 : 1.5), strokeOpacity: (r: any) => (r.m === 11 ? 1 : 0.55) }),
        W >= 560 ? Plot.text([rr.filter((r) => r.m === 11).at(-1)!], { x: 'date', y: 'r', text: () => 'Decembers', dx: 8, textAnchor: 'start', fill: C.actual, fontWeight: 650, fontSize: 12 }) : null,
        Plot.tip(rr, Plot.pointerX({ x: 'date', y: 'r', title: (r: any) => `${ym(r.date)}\nRemainder: ${add ? `$${r.r.toFixed(2)}bn` : `${r.r.toFixed(1)}%`}` })),
      ].filter(Boolean) as any,
    });
    p1.setAttribute('aria-label', `E-commerce sales and the ${type} decomposition fit`);
    p2.setAttribute('aria-label', `Remainder of the ${type} decomposition; December bars highlighted`);
    el.replaceChildren(p1, p2);
  }
  $effect(() => { fit; draw(); });
  onMount(() => watchLayout(el, draw));
</script>

<Explorable title="When the swings grow, the seasonal effect is a percentage" caption="Classical decomposition (R's <code>decompose()</code>) of U.S. e-commerce sales, NSA, 2000–2019. <b>Additive</b> assumes every December adds the same number of dollars. <b>Multiplicative</b> assumes every December adds the same percentage. Watch the gold December bars in the remainder: a model that fits leaves them scattered around zero.">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Decomposition type">
      <button class:on={type === 'additive'} aria-pressed={type === 'additive'} onclick={() => (type = 'additive')}>Additive: Y = T + S + R</button>
      <button class:on={type === 'multiplicative'} aria-pressed={type === 'multiplicative'} onclick={() => (type = 'multiplicative')}>Multiplicative: Y = T × S × R</button>
    </div>
  {/snippet}
  {#snippet aside()}
    {#if fit}
      <div class="ro">
        <div class="stat"><span class="stat-v">{type === 'additive' ? `+$${fit.d2000.toFixed(1)}bn` : `+${(100 * (fit.fig - 1)).toFixed(1)}%`}</span><span class="stat-l">the model's December effect, {type === 'additive' ? 'in dollars, the same every year' : 'in percent, the same every year'}</span></div>
        <div class="stat"><span class="stat-v">${fit.d2000.toFixed(1)}bn → ${fit.d2018.toFixed(1)}bn</span><span class="stat-l">implied December boost in 2000 vs 2018</span></div>
        <div class="stat"><span class="stat-v">{fit.acf12.toFixed(2)}</span><span class="stat-l">correlation of the remainder with itself 12 months earlier. High = seasonal pattern left over.</span></div>
        <p class="note">{type === 'additive' ? 'The December remainders march from big negatives to big positives: one fixed dollar amount is too large for 2000 and far too small for 2018.' : 'Most of the pattern is gone. What is left reflects December’s share changing over 20 years, which a fixed pattern cannot follow. STL, below, can.'}</p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart" aria-label="E-commerce sales decomposition"></div>
</Explorable>

<style>
  .chart { min-height: 400px; }
  .ro { display: grid; gap: .9rem; font-size: .82rem; }
  .stat-l { line-height: 1.4; }
  .note { margin: 0; color: var(--text-2); line-height: 1.5; border-top: 1px solid var(--border); padding-top: .7rem; }
</style>
