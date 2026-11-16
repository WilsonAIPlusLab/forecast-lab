<script lang="ts">
  // Functional-form switcher: put sales and/or gas in logs and watch the gas coefficient change its meaning
  // (units, percent, elasticity), while the business answer ("what if gas goes to $X?") stays comparable.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { carRows, fitForm, type CarRow } from './interp';

  let rows: CarRow[] = $state([]);
  let yLog = $state(false), xLog = $state(false);
  let newGas = $state(5);
  let el: HTMLDivElement;

  onMount(() => {
    (async () => {
      const [veh, gas, un, mr] = await Promise.all([
        loadSeries('TOTALSA'), loadSeries('GASREGW', { to: 'month' }), loadSeries('UNRATE'), loadSeries('MORTGAGE30US', { to: 'month' }),
      ]);
      rows = carRows(veh.data, gas.data, un.data, mr.data);
    })();
    return watchLayout(el, draw);
  });

  const FORMS = [
    { y: false, x: false, name: 'level–level' }, { y: true, x: false, name: 'log–level' },
    { y: false, x: true, name: 'level–log' }, { y: true, x: true, name: 'log–log' },
  ];
  const fits = $derived(rows.length ? FORMS.map((f) => ({ ...f, fit: fitForm(rows, f.y, f.x) })) : []);
  const last = $derived(rows.length ? rows[rows.length - 1] : null);
  // Predicted sales (millions, SAAR) at gas price g, with unemployment and mortgage rate at today's values, chip = 0.
  function pred(k: number, g: number) {
    const f = fits[k], b = f.fit.beta, L = last!;
    const lin = b[0] + b[1] * (f.x ? Math.log(g) : g) + b[2] * L.un + b[3] * L.mr;
    return f.y ? Math.exp(lin) : lin;
  }
  const sel = $derived(FORMS.findIndex((f) => f.y === yLog && f.x === xLog));

  const out = $derived.by(() => {
    if (!fits.length || !last) return null;
    const g0 = last.gas, g1 = +newGas, dG = g1 - g0, pG = 100 * (g1 / g0 - 1);
    const all = FORMS.map((_, k) => pred(k, g1) - pred(k, g0));
    const b = fits[sel].fit.beta[1], s0 = pred(sel, g0);
    let approx = '', exact = '', words = '', unit = '';
    if (sel === 0) { words = `Each extra $1 a gallon goes with <b>${Math.abs(b).toFixed(2)} million</b> ${b < 0 ? 'fewer' : 'more'} cars a year, holding unemployment and mortgage rates fixed.`; unit = 'million cars per $1';
      approx = `${b.toFixed(3)} × ${dG.toFixed(2)} = ${(b * dG).toFixed(3)} mn`; exact = 'Same: a straight line has no approximation'; }
    if (sel === 1) { words = `Each extra $1 a gallon goes with about <b>${Math.abs(100 * b).toFixed(1)}%</b> ${b < 0 ? 'fewer' : 'more'} cars (100 × b), holding the other drivers fixed.`; unit = 'log points per $1 (× 100 ≈ %)';
      approx = `100 × ${b.toFixed(4)} × ${dG.toFixed(2)} = ${(100 * b * dG).toFixed(2)}%`; exact = `100 × (e<sup>b×Δ</sup> − 1) = ${(100 * (Math.exp(b * dG) - 1)).toFixed(2)}%`; }
    if (sel === 2) { words = `A 1% rise in the gas price goes with <b>${Math.abs(b / 100).toFixed(4)} million</b> (${Math.round(Math.abs(b / 100) * 1e6).toLocaleString()}) ${b < 0 ? 'fewer' : 'more'} cars a year (b ÷ 100).`; unit = 'million cars per unit of log(gas)';
      approx = `${(b / 100).toFixed(4)} × ${pG.toFixed(1)} = ${((b / 100) * pG).toFixed(3)} mn`; exact = `b × ln(${g1.toFixed(2)}/${g0.toFixed(2)}) = ${(b * Math.log(g1 / g0)).toFixed(3)} mn`; }
    if (sel === 3) { words = `<b>Elasticity:</b> a 1% rise in the gas price goes with about <b>${Math.abs(b).toFixed(3)}%</b> ${b < 0 ? 'fewer' : 'more'} cars, holding the other drivers fixed.`; unit = '% per 1% (no units)';
      approx = `${b.toFixed(4)} × ${pG.toFixed(1)} = ${(b * pG).toFixed(2)}%`; exact = `100 × ((${g1.toFixed(2)}/${g0.toFixed(2)})<sup>b</sup> − 1) = ${(100 * (Math.pow(g1 / g0, b) - 1)).toFixed(2)}%`; }
    return { g0, g1, dG, pG, all, b, s0, s1: pred(sel, g1), approx, exact, words, unit, r2: fits[sel].fit.r2 };
  });

  function draw() {
    if (!el || !out || !last) return;
    const W = el.clientWidth;
    const xs = Array.from({ length: 121 }, (_, i) => 0.8 + (i * (6.6 - 0.8)) / 120);
    const curves = FORMS.flatMap((f, k) => xs.map((g) => ({ k, g, s: pred(k, g), name: f.name })));
    const ends = FORMS.map((f, k) => ({ k, g: 6.6, s: pred(k, 6.6), name: f.name }));
    // spread the right-hand labels so they do not collide
    const order = ends.slice().sort((a, b) => b.s - a.s);
    order.forEach((e, i) => { (e as any).ly = i === 0 ? e.s : Math.min(e.s, (order[i - 1] as any).ly - 0.42); });
    const p0 = { g: out.g0, s: out.s0 }, p1 = { g: out.g1, s: out.s1 };
    const narrow = W < 520;
    const sv = curves.map((c) => c.s), yHi = Math.max(...sv) + 0.3, yLo = Math.min(...sv) - 1.0;
    const rug = (yHi - yLo) * 0.06;
    const chart = Plot.plot({
      width: W, height: Math.max(280, Math.min(360, W * 0.48)), marginLeft: 50, marginRight: narrow ? 74 : 92, marginTop: 14, marginBottom: 38,
      style: plotStyle(),
      x: { label: 'Gas price, $ per gallon →', domain: [0.8, 6.6], tickFormat: (v: number) => '$' + v },
      y: { grid: true, label: null, domain: [yLo, yHi], tickFormat: (v: number) => v + ' mn' },
      ariaLabel: `Predicted vehicle sales against the gas price under four functional forms; the ${FORMS[sel].name} form is highlighted`,
      marks: [
        Plot.ruleX(rows, { x: 'gas', y1: () => yLo, y2: () => yLo + rug, stroke: C.muted, strokeOpacity: 0.25 }),
        Plot.line(curves.filter((c) => c.k !== sel), { x: 'g', y: 's', z: 'k', stroke: C.muted, strokeWidth: 1.25, strokeOpacity: 0.4 }),
        Plot.line(curves.filter((c) => c.k === sel), { x: 'g', y: 's', stroke: C.fitted, strokeWidth: 3 }),
        Plot.text(ends.filter((e) => e.k !== sel), { x: 'g', y: (d: any) => d.ly, text: 'name', dx: 6, textAnchor: 'start', fontSize: 12, fill: C.muted }),
        Plot.text(ends.filter((e) => e.k === sel), { x: 'g', y: (d: any) => d.ly, text: 'name', dx: 6, textAnchor: 'start', fontSize: 12, fill: C.fitted, fontWeight: 700 }),
        Plot.ruleX([p0, p1], { x: 'g', y1: (d: any) => d.s, y2: () => yLo + rug, stroke: C.borderStrong, strokeDasharray: '3 3' }),
        Plot.link([{ a: p0, b: p1 }], { x1: (d: any) => d.a.g, y1: (d: any) => d.a.s, x2: (d: any) => d.b.g, y2: (d: any) => d.a.s, stroke: C.text2, strokeWidth: 1.5 }),
        Plot.link([{ a: p0, b: p1 }], { x1: (d: any) => d.b.g, y1: (d: any) => d.a.s, x2: (d: any) => d.b.g, y2: (d: any) => d.b.s, stroke: C.actual, strokeWidth: 2.5, markerEnd: 'arrow' }),
        Plot.dot([p0, p1], { x: 'g', y: 's', r: 5, fill: C.fitted, stroke: C.surface, strokeWidth: 1.5 }),
        Plot.text([p0], { x: 'g', y: 's', text: () => `Today $${out.g0.toFixed(2)}`, dy: -10, dx: -8, textAnchor: 'end', fill: C.text2, fontSize: 12, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
        Plot.text([{ g: p1.g, s: (p0.s + p1.s) / 2 }], { x: 'g', y: 's', text: () => `${out.s1 - out.s0 >= 0 ? '+' : '−'}${Math.abs(out.s1 - out.s0).toFixed(2)} mn`, dx: 8, textAnchor: 'start', fill: C.text, fontWeight: 700, fontSize: 12, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
        Plot.text([narrow ? 'Ticks: gas prices seen' : 'Ticks at the bottom: gas prices actually seen, 1993–2026'], { frameAnchor: 'top-right', textAnchor: 'end', dy: 4, dx: -4, fill: C.muted, fontSize: 12, text: (d: any) => d }),
        Plot.tip(curves.filter((c) => c.k === sel), Plot.pointerX({ x: 'g', y: 's', title: (d: any) => `Gas $${d.g.toFixed(2)}/gal\nPredicted sales: ${d.s.toFixed(2)} mn (SAAR)\nForm: ${d.name}` })),
      ],
    });
    el.replaceChildren(chart);
  }
  $effect(() => { out; sel; draw(); });
  const sgn = (v: number) => (v >= 0 ? '+' : '−') + Math.abs(v).toFixed(2);
</script>

<Explorable title="Same data, four forms: the coefficient's meaning changes, the question doesn't"
  caption="A regression of light vehicle sales (millions of units, seasonally adjusted annual rate) on the gas price, the unemployment rate, the 30-year mortgage rate and the 2021–22 chip-shortage dummy, January 1993 to the latest month. Switch <b>Sales</b> and <b>Gas</b> between levels and logs: the gas coefficient changes its units and its reading, shown in words on the right. Then drag the new gas price. Each curve holds unemployment and the mortgage rate at today's values. <b>Takeaway:</b> translate every coefficient into the same business answer before you compare models. Data: FRED (TOTALSA, GASREGW, UNRATE, MORTGAGE30US).">
  {#snippet controls()}
    <div class="grp"><span class="lab" id="fs-y">Sales</span>
      <div class="seg" role="group" aria-labelledby="fs-y">
        <button class:on={!yLog} aria-pressed={!yLog} onclick={() => (yLog = false)}>Level</button>
        <button class:on={yLog} aria-pressed={yLog} onclick={() => (yLog = true)}>Log</button>
      </div></div>
    <div class="grp"><span class="lab" id="fs-x">Gas</span>
      <div class="seg" role="group" aria-labelledby="fs-x">
        <button class:on={!xLog} aria-pressed={!xLog} onclick={() => (xLog = false)}>Level</button>
        <button class:on={xLog} aria-pressed={xLog} onclick={() => (xLog = true)}>Log</button>
      </div></div>
    <label class="sl">Gas goes to <input type="range" min="2" max="6.5" step="0.05" bind:value={newGas} aria-label="New gas price, dollars per gallon" aria-valuetext={`$${(+newGas).toFixed(2)} per gallon`} /> <b>${(+newGas).toFixed(2)}</b></label>
  {/snippet}
  {#snippet aside()}
    {#if out}
      <div class="fs">
        <div class="form">{FORMS[sel].name}: <code>{yLog ? 'log(sales)' : 'sales'} = a + b·{xLog ? 'log(gas)' : 'gas'} + …</code></div>
        <div class="stat"><span class="stat-v">b = {out.b.toFixed(4)}</span><span class="stat-l">Units of b: {out.unit}</span></div>
        <p class="words">{@html out.words}</p>
        <div class="move">
          <div class="mh">Your move: ${out.g0.toFixed(2)} → ${out.g1.toFixed(2)} ({out.pG >= 0 ? '+' : '−'}{Math.abs(out.pG).toFixed(1)}%)</div>
          <div class="mr"><span>Rule of thumb</span><span>{@html out.approx}</span></div>
          <div class="mr"><span>Exact</span><span>{@html out.exact}</span></div>
          <div class="mr tot"><span>In cars</span><span><b>{sgn(out.s1 - out.s0)} million</b> a year</span></div>
        </div>
        <div class="all" aria-label="The same move under all four forms">
          <div class="mh">Same move, all four forms</div>
          {#each FORMS as f, k}<div class="ar" class:on={k === sel}><span>{f.name}</span><span>{sgn(out.all[k])} mn</span></div>{/each}
        </div>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 280px; }
  .grp { display: inline-flex; align-items: center; gap: .45rem; }
  .lab { color: var(--muted); }
  .fs { display: grid; gap: .75rem; font-size: .82rem; }
  .form { color: var(--text-2); font-weight: 650; }
  .form code { font-size: .74rem; display: block; margin-top: .2rem; white-space: normal; }
  .stat-v { font-size: 1.3rem !important; }
  .words { margin: 0; line-height: 1.45; color: var(--text); }
  .mh { font-weight: 650; color: var(--text-2); margin-bottom: .25rem; }
  .mr, .ar { display: grid; grid-template-columns: 6.2rem 1fr; gap: .4rem; padding: .12rem 0; font-variant-numeric: tabular-nums; }
  .mr span:first-child, .ar span:first-child { color: var(--muted); }
  .mr span:last-child { color: var(--text); word-break: break-word; }
  .tot { border-top: 1px solid var(--border); margin-top: .2rem; padding-top: .3rem; }
  .ar span:last-child { text-align: right; color: var(--text-2); }
  .ar.on span { color: var(--text); font-weight: 700; }
</style>
