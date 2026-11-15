<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';

  // Advance estimates for two teaching quarters (BEA news releases of Apr 29, 2015 and Apr 30, 2025).
  const ADVANCE: Record<string, number> = { '2015-01': 0.2, '2025-01': -0.3 };
  let view: 'scatter' | 'time' = $state('scatter');
  let covid = $state(false);
  let rows: { d: Date; q: string; key: string; now: number; act: number; err: number }[] = $state([]);
  let el: HTMLDivElement;

  const qLab = (d: Date) => `${d.getFullYear()} Q${Math.floor(d.getMonth() / 3) + 1}`;
  async function load() {
    const [n, a] = await Promise.all([loadSeries('GDPNOW'), loadSeries('A191RL1Q225SBEA')]);
    const am = new Map(a.data.map((p) => [+p.date, p.value]));
    rows = n.data.filter((p) => am.has(+p.date)).map((p) => {
      const act = am.get(+p.date)!;
      return { d: p.date, q: qLab(p.date), key: `${p.date.getFullYear()}-${String(p.date.getMonth() + 1).padStart(2, '0')}`, now: p.value, act, err: act - p.value };
    });
  }
  onMount(() => { load(); return watchLayout(el, draw); });

  const isCovid = (r: { key: string }) => r.key === '2020-04' || r.key === '2020-07';
  const use = $derived(rows.filter((r) => covid || !isCovid(r)));
  const stats = $derived.by(() => {
    if (!use.length) return null;
    const e = use.map((r) => r.err);
    return { n: e.length, mae: e.reduce((s, v) => s + Math.abs(v), 0) / e.length, rmse: Math.sqrt(e.reduce((s, v) => s + v * v, 0) / e.length), me: e.reduce((s, v) => s + v, 0) / e.length, within1: e.filter((v) => Math.abs(v) < 1).length };
  });

  function draw() {
    if (!el || !use.length) return;
    const W = el.clientWidth;
    const tip = (r: any) => `${r.q}\nGDPNow final: ${r.now.toFixed(1)}%\nGDP growth today: ${r.act.toFixed(1)}%\nMiss: ${r.err >= 0 ? '+' : ''}${r.err.toFixed(1)} pts (annualized %)`;
    let chart: any;
    if (view === 'scatter') {
      const v = use.flatMap((r) => [r.now, r.act]);
      const lo = Math.min(...v), hi = Math.max(...v), pad = (hi - lo) * 0.06;
      const dom = [lo - pad, hi + pad];
      const ghosts = use.filter((r) => ADVANCE[r.key] !== undefined).map((r) => ({ ...r, adv: ADVANCE[r.key] }));
      const big = use.slice().sort((a, b) => Math.abs(b.err) - Math.abs(a.err)).slice(0, 3).filter((r) => !ADVANCE[r.key]);
      chart = Plot.plot({
        width: W, height: Math.min(460, W * 0.7), marginLeft: 50, marginBottom: 44, marginRight: 24, style: plotStyle(),
        x: { domain: dom, grid: true, label: 'GDPNow final nowcast (% annualized) →' },
        y: { domain: dom, grid: true, label: '↑ Real GDP growth, today’s revised data (%)' },
        marks: [
          Plot.ruleX([0], { stroke: C.borderStrong }), Plot.ruleY([0], { stroke: C.borderStrong }),
          Plot.line([[dom[0], dom[0]], [dom[1], dom[1]]], { stroke: C.actual, strokeWidth: 2, strokeDasharray: '4 4' }),
          Plot.text([[dom[1], dom[1]]], { text: () => 'perfect nowcast', textAnchor: 'end', dx: -6, dy: -10, fill: C.actual, fontSize: 12 }),
          Plot.link(ghosts, { x1: 'now', y1: 'adv', x2: 'now', y2: 'act', stroke: C.text2, strokeDasharray: '2 3', markerEnd: 'arrow' }),
          Plot.dot(ghosts, { x: 'now', y: 'adv', r: 5, stroke: C.text2, fill: 'none', strokeWidth: 1.5 }),
          Plot.text(ghosts.filter((r) => r.key === '2015-01'), { x: 'now', y: 'act', text: (r: any) => `${r.q}: advance ${r.adv.toFixed(1)}% → revised ${r.act.toFixed(1)}%`, dx: -10, textAnchor: 'end', fill: C.text, fontSize: 12, fontWeight: 600, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' } as any),
          Plot.text(ghosts.filter((r) => r.key === '2025-01'), { x: 'now', y: 'adv', text: (r: any) => `${r.q}: advance ${r.adv.toFixed(1)}% → revised ${r.act.toFixed(1)}%`, dy: 18, dx: -4, textAnchor: 'start', fill: C.text, fontSize: 12, fontWeight: 600, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' } as any),
          Plot.dot(use, { x: 'now', y: 'act', r: 4.5, fill: C.forecast, fillOpacity: 0.75, stroke: C.surface, strokeWidth: 1 }),
          Plot.text(big, { x: 'now', y: 'act', text: 'q', dx: 8, textAnchor: 'start', fill: C.text2, fontSize: 12, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' } as any),
          Plot.tip(use, Plot.pointer({ x: 'now', y: 'act', title: tip })),
        ],
      });
      chart.setAttribute('aria-label', 'Scatter of GDPNow final nowcasts against real GDP growth as revised today. Points cluster around the 45-degree line; misses of one to four points are common.');
    } else {
      chart = Plot.plot({
        width: W, height: 300, marginLeft: 50, marginRight: 16, style: plotStyle(),
        x: { label: null }, y: { grid: true, label: '↑ Revised GDP growth minus final nowcast (pct. points)' },
        marks: [
          Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
          Plot.rectY(use, { x1: (r: any) => new Date(+r.d + 10 * 864e5), x2: (r: any) => new Date(+r.d + 80 * 864e5), y: 'err', fill: (r: any) => (r.err >= 0 ? C.s[0] : C.s[1]), fillOpacity: 0.85 }),
          Plot.text(use.filter((r) => r.err > 3), { x: 'd', y: 'err', text: 'q', dy: -8, fill: C.text2, fontSize: 12 }),
          Plot.text(use.filter((r) => r.err < -3), { x: 'd', y: 'err', text: 'q', dy: 12, fill: C.text2, fontSize: 12 }),
          Plot.tip(use, Plot.pointerX({ x: 'd', y: 'err', title: tip })),
        ],
      });
      chart.setAttribute('aria-label', 'Bar chart of GDPNow misses by quarter since 2011, positive when growth came in above the nowcast.');
    }
    el.replaceChildren(chart);
  }
  $effect(() => { use; view; draw(); });
</script>

<Explorable title="GDPNow's track record, and the moving target" caption="Each dot is one quarter from 2011 Q3 to 2026 Q3: the Atlanta Fed's final GDPNow nowcast, made just before BEA's advance estimate, against real GDP growth <b>as revised today</b>. Hollow circles show the advance estimate for two quarters. The arrows show how far later revisions moved the target. Annualized %, SA. Data: FRED (GDPNOW, A191RL1Q225SBEA); advance estimates from BEA news releases.">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="View">
      <button class:on={view === 'scatter'} aria-pressed={view === 'scatter'} onclick={() => (view = 'scatter')}>Nowcast vs outcome</button>
      <button class:on={view === 'time'} aria-pressed={view === 'time'} onclick={() => (view = 'time')}>Miss by quarter</button>
    </div>
    <label class="ck"><input type="checkbox" bind:checked={covid} /> Include 2020 Q2–Q3</label>
  {/snippet}
  {#snippet aside()}
    {#if stats}
      <div class="side" aria-live="polite">
        <div class="eyebrow">{stats.n} quarters{covid ? '' : ', excluding 2020 Q2–Q3'}</div>
        <div class="kp"><span class="v">{stats.mae.toFixed(2)}</span><span class="l">mean absolute miss, pct. points</span></div>
        <div class="kp"><span class="v">{stats.rmse.toFixed(2)}</span><span class="l">root mean squared miss</span></div>
        <div class="kp"><span class="v">{stats.me >= 0 ? '+' : ''}{stats.me.toFixed(2)}</span><span class="l">mean miss (+ = growth came in higher)</span></div>
        <div class="kp"><span class="v">{stats.within1}/{stats.n}</span><span class="l">within 1 point</span></div>
        <div class="eyebrow" style="margin-top:.7rem">Which truth?</div>
        <p class="note">Against the <b>advance</b> estimate, the Atlanta Fed reports an average miss of <b>0.76</b> points (2011 Q3 to 2026 Q3). BEA finds growth is revised by <b>1.21</b> points on average between the advance and latest estimates (1999–2022). Much of the gap above is revision, not nowcast error.</p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 300px; }
  .ck { display: inline-flex; gap: .45rem; align-items: center; font-size: .84rem; }
  .side { font-size: .82rem; }
  .kp { display: flex; flex-direction: column; margin: .45rem 0; }
  .kp .v { font: 700 1.35rem/1.1 var(--font-ui); color: var(--text); font-variant-numeric: tabular-nums; }
  .kp .l { color: var(--muted); font-size: .76rem; }
  .note { color: var(--text-2); margin: .3rem 0 0; }
</style>
