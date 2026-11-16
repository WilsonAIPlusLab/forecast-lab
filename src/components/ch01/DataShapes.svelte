<script lang="ts">
  // Three shapes of data from one source (Census monthly retail trade, by store type):
  // a cross-section (one year, many store types), a time series (one store type, many months),
  // and a panel (many store types × many years). Selecting a store type links all three.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { monthLabel } from './util';

  const CATS = [
    { id: 'MRTSSM454USN', name: 'Nonstore (online)' },
    { id: 'MRTSSM722USN', name: 'Restaurants & bars' },
    { id: 'MRTSSM441USN', name: 'Motor vehicles' },
    { id: 'MRTSSM445USN', name: 'Grocery & beverage' },
    { id: 'MRTSSM452USN', name: 'General merchandise' },
    { id: 'MRTSSM447USN', name: 'Gas stations' },
  ];
  const Y0 = 2015, Y1 = 2025; // complete calendar years
  const XS = Y1; // the cross-section year

  let data: Record<string, { date: Date; value: number }[]> = $state({});
  let sel = $state('MRTSSM454USN');
  let elX: HTMLDivElement, elT: HTMLDivElement, elP: HTMLDivElement;

  onMount(() => {
    Promise.all(CATS.map((c) => loadSeries(c.id, { start: `${Y0 - 1}-01-01` }).then((s) => [c.id, s.data] as const))).then((r) => (data = Object.fromEntries(r)));
    const off = [elX, elT, elP].map((e) => watchLayout(e, draw));
    return () => off.forEach((f) => f());
  });

  const annual = $derived.by(() => {
    if (!Object.keys(data).length) return null;
    const rows: { id: string; name: string; year: number; total: number; growth: number }[] = [];
    for (const c of CATS) {
      const tot = new Map<number, number>();
      for (const p of data[c.id] ?? []) tot.set(p.date.getFullYear(), (tot.get(p.date.getFullYear()) ?? 0) + p.value);
      for (let y = Y0; y <= Y1; y++) rows.push({ id: c.id, name: c.name, year: y, total: tot.get(y)! / 1000, growth: 100 * (tot.get(y)! / tot.get(y - 1)! - 1) });
    }
    return rows;
  });
  const selName = $derived(CATS.find((c) => c.id === sel)!.name);
  const selRow = $derived(annual?.find((r) => r.id === sel && r.year === XS));

  function draw() {
    if (!annual || !elX) return;
    const xs = annual.filter((r) => r.year === XS).sort((a, b) => b.total - a.total);
    const wX = elX.clientWidth, wT = elT.clientWidth, wP = elP.clientWidth;
    if (!wX || !wT || !wP) return;   // hidden (e.g. inside a closed <details>): watchLayout redraws once it has a width
    const st = plotStyle();

    const cx = Plot.plot({
      width: wX, height: 230, marginLeft: 138, marginRight: 52, style: st,
      x: { grid: true, label: null, tickFormat: (v: number) => `$${v}bn`, ticks: 4 }, y: { label: null, domain: xs.map((r) => r.name) },
      marks: [
        Plot.barX(xs, { y: 'name', x: 'total', fill: (r: any) => (r.id === sel ? C.fitted : C.history), fillOpacity: (r: any) => (r.id === sel ? 1 : 0.35), className: 'ds-bar' }),
        Plot.text(xs, { y: 'name', x: 'total', text: (r: any) => `$${Math.round(r.total).toLocaleString('en-US')}bn`, dx: 5, textAnchor: 'start', fill: C.text2, fontSize: 12 }),
        Plot.ruleX([0], { stroke: C.borderStrong }),
      ],
    });
    cx.setAttribute('role', 'img'); cx.setAttribute('aria-label', `Cross-section: annual sales by store type in ${XS}`);
    elX.replaceChildren(cx);
    cx.querySelectorAll('.ds-bar rect').forEach((r, i) => { (r as SVGElement).style.cursor = 'pointer'; r.addEventListener('click', () => (sel = xs[i].id)); });

    const ts = data[sel].filter((p) => p.date.getFullYear() >= Y0);
    const ct = Plot.plot({
      width: wT, height: 230, marginLeft: 52, marginRight: 12, style: st,
      x: { label: null }, y: { grid: true, label: null, tickFormat: (v: number) => `$${v / 1000}bn` },
      marks: [
        Plot.rectX([XS], { x1: (y: number) => new Date(y, 0, 1), x2: (y: number) => new Date(y + 1, 0, 1), fill: C.actual, fillOpacity: 0.12 }),
        Plot.lineY(ts, { x: 'date', y: 'value', stroke: C.fitted, strokeWidth: 2 }),
        Plot.tip(ts, Plot.pointerX({ x: 'date', y: 'value', title: (p: any) => `${selName}\n${monthLabel(p.date)}: $${(p.value / 1000).toFixed(1)}bn` })),
      ],
    });
    ct.setAttribute('role', 'img'); ct.setAttribute('aria-label', `Time series: monthly sales of ${selName}, ${Y0} to latest`);
    elT.replaceChildren(ct);

    const cp = Plot.plot({
      width: wP, height: 250, marginLeft: 138, marginRight: 12, marginTop: 8, style: st, padding: 0.06,
      x: { label: null, type: 'band', tickFormat: (y: number) => `${y}` }, y: { label: null, domain: CATS.map((c) => c.name) },
      color: { type: 'diverging', scheme: 'PuOr', pivot: 0, domain: [-25, 25], clamp: true },
      marks: [
        Plot.cell(annual, { x: 'year', y: 'name', fill: 'growth', inset: 0.5, fillOpacity: (r: any) => (r.id === sel || r.year === XS ? 1 : 0.55) }),
        Plot.text(annual.filter((r) => Math.abs(r.growth) > 15), { x: 'year', y: 'name', text: (r: any) => `${r.growth > 0 ? '+' : '−'}${Math.abs(r.growth).toFixed(0)}`, fill: '#fff', fontSize: 12 }),
        Plot.text(annual.filter((r) => Math.abs(r.growth) <= 15), { x: 'year', y: 'name', text: (r: any) => `${r.growth > 0 ? '+' : r.growth < 0 ? '−' : ''}${Math.abs(r.growth).toFixed(0)}`, fill: '#111', fontSize: 12 }),
        Plot.cell([XS], { x: (d: number) => d, fill: 'none', stroke: C.actual, strokeWidth: 2.5 }),
        Plot.cell([selName], { y: (d: string) => d, fill: 'none', stroke: C.fitted, strokeWidth: 2.5 }),
        Plot.tip(annual, Plot.pointer({ x: 'year', y: 'name', title: (r: any) => `${r.name}, ${r.year}\nSales: $${Math.round(r.total).toLocaleString('en-US')}bn\nGrowth: ${r.growth > 0 ? '+' : ''}${r.growth.toFixed(1)}% vs ${r.year - 1}` })),
      ],
    });
    cp.setAttribute('role', 'img'); cp.setAttribute('aria-label', 'Panel: annual sales growth by store type and year');
    elP.replaceChildren(cp);
  }

  $effect(() => { annual; sel; draw(); });
</script>

<Explorable title="Cross-section, time series, panel: three ways to slice the same retail data" caption={`All three charts come from the Census Bureau's monthly retail trade survey (not seasonally adjusted, via FRED). Pick a store type: the <b>cross-section</b> compares store types in one year (${XS}), the <b>time series</b> follows one store type month by month, and the <b>panel</b> holds both at once. Its gold column is the cross-section; its cyan row is the time series, summed to years. Numbers in the panel are % growth over the previous year.`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Store type">
      {#each CATS as c}<button class:on={sel === c.id} aria-pressed={sel === c.id} onclick={() => (sel = c.id)}>{c.name}</button>{/each}
    </div>
  {/snippet}
  <div class="grid">
    <div>
      <div class="lbl"><b>Cross-section.</b> Many units, one period: sales by store type, {XS}</div>
      <div bind:this={elX} class="c"></div>
    </div>
    <div>
      <div class="lbl"><b>Time series.</b> One unit, many periods: {selName}, monthly, $ billions</div>
      <div bind:this={elT} class="c"></div>
    </div>
  </div>
  <div class="lbl"><b>Panel.</b> Many units × many periods: annual growth, % vs. previous year</div>
  <div bind:this={elP} class="c"></div>
  {#if selRow}<p class="sr">{selName} sold ${Math.round(selRow.total).toLocaleString('en-US')} billion in {XS}, {selRow.growth > 0 ? 'up' : 'down'} {Math.abs(selRow.growth).toFixed(1)}% from {XS - 1}.</p>{/if}
</Explorable>

<style>
  .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1.2rem; margin-bottom: 1rem; }
  @media (max-width: 760px) { .grid { grid-template-columns: 1fr; } }
  .c { min-height: 230px; min-width: 0; }
  .grid > div { min-width: 0; }
  .lbl { font-size: .84rem; color: var(--text-2); margin-bottom: .3rem; }
  .lbl b { color: var(--text); }
  .sr { font-size: .84rem; color: var(--muted); margin: .4rem 0 0; }
</style>
