<script lang="ts">
  // Read the Census seasonal factor of any month: factor = NSA / SA, said in percent and in dollars,
  // its drift across years, and what happens when an SA month is compared with an NSA month.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries } from '../../lib/ts';
  import { C, watchLayout } from '../../lib/viz/theme';

  type Row = { date: Date; yr: number; m: number; nsa: number; sa: number; f: number };
  let rows: Row[] = $state([]);
  let i = $state(0);
  let el: HTMLDivElement;
  const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  onMount(async () => {
    const [r, a, f] = await Promise.all([loadSeries('RSXFSN', { start: '2015-01-01' }), loadSeries('RSAFS', { start: '2015-01-01' }), loadSeries('RSFSDP', { start: '2015-01-01' })]);
    const k = (d: Date) => `${d.getFullYear()}-${d.getMonth()}`;
    const am = new Map(a.data.map((p) => [k(p.date), p.value]));
    const fm = new Map(f.data.map((p) => [k(p.date), p.value]));
    rows = r.data.filter((p) => am.has(k(p.date)) && fm.has(k(p.date))).map((p) => {
      const sa = am.get(k(p.date))! - fm.get(k(p.date))!;   // Census SA retail excl. food services
      return { date: p.date, yr: p.date.getFullYear(), m: p.date.getMonth(), nsa: p.value / 1000, sa: sa / 1000, f: p.value / sa };
    });
    const dec = rows.map((x, j) => (x.m === 11 ? j : -1)).filter((j) => j >= 0);
    i = dec[dec.length - 1];
  });

  const pc = (a: number, b: number) => 100 * (a / b - 1);
  const f1 = (x: number) => (x > 0 ? '+' : x < 0 ? '−' : '') + Math.abs(x).toFixed(1) + '%';
  const label = (d: Date) => d.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
  const v = $derived.by(() => {
    if (!rows.length) return null;
    const r = rows[i], p = i > 0 ? rows[i - 1] : null;
    return {
      r, p, pctAbove: 100 * (r.f - 1), boost: r.nsa - r.sa,
      saSa: p ? pc(r.sa, p.sa) : NaN, nsaNsa: p ? pc(r.nsa, p.nsa) : NaN, mixed: p ? pc(r.sa, p.nsa) : NaN,
      year: rows.filter((x) => x.yr === r.yr), same: rows.filter((x) => x.m === r.m),
    };
  });

  const style = () => ({ background: 'transparent', color: C.muted, fontSize: '12px', fontFamily: 'var(--font-ui)', overflow: 'visible' as const });
  function draw() {
    if (!el || !v) return;
    const W = el.clientWidth;
    const stack = W < 560;                                   // one chart per row on phones
    const wEach = stack ? W : Math.floor((W - 24) / 2) - 1;
    const narrow = wEach < 440;                              // short tick labels when space is tight
    const yr = v.year.map((x) => ({ ...x, p: 100 * (x.f - 1), lab: MON[x.m] }));
    const sm = v.same.map((x) => ({ ...x, p: 100 * (x.f - 1), lab: String(x.yr) }));
    const lim = Math.max(18, ...yr.map((x) => Math.abs(x.p)), ...sm.map((x) => Math.abs(x.p)));
    const mk = (data: any[], sel: (x: any) => boolean, title: string, aria: string, xLab: (d: string) => string) => {
      const p = Plot.plot({
        width: wEach, height: 190, marginLeft: 36, marginRight: 6, marginTop: 28, marginBottom: 24, style: style(),
        x: { domain: data.map((d) => d.lab), label: null, tickSize: 0, tickFormat: xLab },
        y: { domain: [-lim, lim], grid: true, ticks: 5, label: null, tickFormat: (d: number) => `${d > 0 ? '+' : d < 0 ? '−' : ''}${Math.abs(d)}` },
        marks: [
          Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
          Plot.barY(data, { x: 'lab', y: 'p', fill: (d: any) => (sel(d) ? C.actual : d.p >= 0 ? C.s[0] : C.s[1]), fillOpacity: (d: any) => (sel(d) ? 1 : 0.55) }),
          Plot.text(data.filter((d) => sel(d) && d.p >= 0), { x: 'lab', y: 'p', text: (d: any) => f1(d.p), dy: -8, fill: C.text, fontWeight: 700, fontSize: 12 }),
          Plot.text(data.filter((d) => sel(d) && d.p < 0), { x: 'lab', y: 'p', text: (d: any) => f1(d.p), dy: 10, fill: C.text, fontWeight: 700, fontSize: 12 }),
          Plot.text([title], { frameAnchor: 'top-left', dy: -24, dx: -30, textAnchor: 'start', fill: C.text, fontWeight: 650, fontSize: 12.5 }),
          Plot.tip(data, Plot.pointerX({ x: 'lab', y: 'p', title: (d: any) => `${MON[d.m]} ${d.yr}\nFactor ${d.f.toFixed(3)} = ${f1(d.p)} vs a typical month\nRaw $${d.nsa.toFixed(1)}bn ÷ ${d.f.toFixed(3)} = SA $${d.sa.toFixed(1)}bn` })),
        ],
      });
      p.setAttribute('aria-label', aria);
      return p;
    };
    const a = mk(yr, (d) => d.m === v.r.m, `Every month of ${v.r.yr}, % vs typical`, `Census seasonal factors for each month of ${v.r.yr}, in percent`, (d) => (narrow ? d[0] : d));
    const b = mk(sm, (d) => d.yr === v.r.yr, `Every ${MON[v.r.m]}, ${sm[0].yr}–${sm[sm.length - 1].yr}, %`, `Census seasonal factor for ${MON[v.r.m]} in each year, in percent`, (d) => (narrow ? `’${d.slice(2)}` : d));
    el.replaceChildren(a, b);
  }
  $effect(() => { v; draw(); });
  onMount(() => watchLayout(el, draw));
</script>

<Explorable title="A seasonal factor is a percentage you can say out loud" caption="The Census Bureau's combined seasonal factor for each month is simply raw sales divided by seasonally adjusted sales (it includes trading-day and holiday effects). Pick a month. The first chart shows that year's whole calendar of factors; the second shows the same month in other years. Notice that February jumps in leap years (2016, 2020, 2024) and that December's boost has shrunk since 2015. Data: RSXFSN (NSA) and RSAFS − RSFSDP (SA), U.S. retail sales excl. food services, via FRED.">
  {#snippet controls()}
    {#if rows.length}
      <label class="sl">Month <input type="range" min="1" max={rows.length - 1} bind:value={i} aria-label="Month to read" aria-valuetext={label(rows[i].date)} /> <b class="wide">{label(rows[i].date)}</b></label>
    {/if}
  {/snippet}
  {#snippet aside()}
    {#if v && v.p}
      <div class="ro">
        <div class="lk-h">Growth from {v.p.date.toLocaleDateString('en-US', { month: 'short' })} to {v.r.date.toLocaleDateString('en-US', { month: 'short', year: 'numeric' })}</div>
        <div class="g ok"><span class="g-v">{f1(v.saSa)}</span><span class="g-l"><b>SA vs SA.</b> The right comparison: the underlying pace.</span></div>
        <div class="g"><span class="g-v">{f1(v.nsaNsa)}</span><span class="g-l"><b>Raw vs raw.</b> Mostly calendar.</span></div>
        <div class="g bad"><span class="g-v">{f1(v.mixed)}</span><span class="g-l"><b>SA this month vs raw last month.</b> Meaningless: it removes the seasonal effect from one month only.</span></div>
      </div>
    {/if}
  {/snippet}
  {#if v}
    <div class="eq" aria-live="polite">
      <span class="eq-p"><span class="eq-k">raw (NSA)</span><b>${v.r.nsa.toFixed(1)}bn</b></span>
      <span class="eq-o">÷</span>
      <span class="eq-p"><span class="eq-k">seasonal factor</span><b>{v.r.f.toFixed(3)}</b></span>
      <span class="eq-o">=</span>
      <span class="eq-p"><span class="eq-k">seasonally adjusted</span><b>${v.r.sa.toFixed(1)}bn</b></span>
    </div>
    <p class="say"><b>Say it in words:</b> {label(v.r.date)} sales ran <b>{Math.abs(v.pctAbove).toFixed(1)}% {v.pctAbove >= 0 ? 'above' : 'below'}</b> a typical month, purely because of the calendar. That is about <b>${Math.abs(v.boost).toFixed(1)}bn</b> {v.boost >= 0 ? 'of extra' : 'of missing'} sales that say nothing about how the business is doing.</p>
  {/if}
  <div bind:this={el} class="chart" aria-label="Seasonal factors by month and by year"></div>
</Explorable>

<style>
  .chart { display: flex; flex-wrap: wrap; gap: 24px; min-height: 190px; }
  .eq { display: flex; flex-wrap: wrap; align-items: flex-end; gap: .4rem .9rem; margin-bottom: .6rem; }
  .eq-p { display: flex; flex-direction: column; }
  .eq-k { font-size: .72rem; color: var(--muted); }
  .eq-p b { font: 650 1.3rem/1.15 var(--font-ui); font-variant-numeric: tabular-nums; color: var(--text); }
  .eq-o { font: 500 1.3rem var(--font-ui); color: var(--muted); padding-bottom: .05rem; }
  .say { margin: 0 0 1rem; font-size: .9rem; color: var(--text-2); line-height: 1.5; }
  .ro { display: grid; gap: .75rem; font-size: .82rem; }
  .lk-h { font-weight: 650; color: var(--text); }
  .g { display: grid; grid-template-columns: 4.6rem 1fr; gap: .6rem; align-items: baseline; border-left: 3px solid var(--border-strong); padding-left: .55rem; }
  .g.ok { border-left-color: var(--good); }
  .g.bad { border-left-color: var(--danger); }
  .g.bad .g-v { text-decoration: line-through; text-decoration-color: var(--danger); }
  .g-v { font: 650 1.15rem var(--font-ui); font-variant-numeric: tabular-nums; color: var(--text); }
  .g-l { color: var(--text-2); line-height: 1.4; }
  .wide { min-width: 9.5rem !important; font-family: var(--font-ui) !important; }
</style>
