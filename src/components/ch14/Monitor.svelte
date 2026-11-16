<script lang="ts">
  // After deployment: watch a live forecast with a tracking signal and decide when to retrain.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries } from '../../lib/ts';
  import { C, css, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { monitor } from './monitor';
  import { seriesById, fmtShort, fmtMiss, monYr } from './series';

  const OPTS = [
    { id: 'MRTSSM4541USS', kind: 'holt', model: 'Holt damped' },
    { id: 'MRTSSM722USN', kind: 'hwm', model: 'Holt-Winters mult.' },
    { id: 'RSXFSN', kind: 'hwm', model: 'Holt-Winters mult.' },
    { id: 'PAYEMS', kind: 'holt', model: 'Holt damped' },
  ] as const;
  let oi = $state(0);
  let thr = $state(4);
  let retrain = $state(true);
  let d: { date: Date; value: number }[] = $state([]);
  let topEl: HTMLDivElement, tsEl: HTMLDivElement;

  const opt = $derived(OPTS[oi]);
  const meta = $derived(seriesById(opt.id));

  $effect(() => { const id = opt.id, div = meta.div; loadSeries(id, { start: '2010-01-01' }).then((s) => { if (opt.id === id) d = s.data.map((p) => ({ date: p.date, value: p.value / div })); }); });

  const out = $derived.by(() => {
    if (!d.length || !d.some((p) => p.date.getFullYear() === 2019)) return null;
    const y = d.map((p) => p.value), t0 = d.findIndex((p) => p.date.getFullYear() === 2019 && p.date.getMonth() === 0);
    const on = monitor(y, t0, opt.kind, thr, true), off = monitor(y, t0, opt.kind, thr, false);
    return { t0, on, off, cur: retrain ? on : off };
  });

  function draw() {
    if (!out || !topEl || !tsEl) return;
    const rows = out.cur.steps.map((s) => ({ ...s, date: d[s.i].date }));
    const alarms = rows.filter((r) => r.alarm);
    const W = topEl.clientWidth;
    if (W < 200) return; // not laid out yet (or mid-resize): skip, watchLayout redraws
    const ctx = d.slice(out.t0 - 24, out.t0 + 1);
    const top = Plot.plot({
      width: W, height: 220, marginLeft: 58, marginRight: 80, marginTop: 16, style: plotStyle(),
      x: { label: null }, y: { grid: true, label: `↑ ${meta.unitAxis}`, tickFormat: (v: number) => fmtShort(meta, v) },
      marks: [
        Plot.ruleX(alarms, { x: 'date', stroke: C.danger, strokeOpacity: 0.5, strokeDasharray: '3,3' }),
        Plot.lineY(ctx, { x: 'date', y: 'value', stroke: C.history, strokeWidth: 1.25, strokeOpacity: 0.4 }),
        Plot.lineY(rows, { x: 'date', y: 'y', stroke: C.actual, strokeWidth: 2 }),
        Plot.lineY(rows, { x: 'date', y: 'f', stroke: C.forecast, strokeWidth: 2, strokeDasharray: '5,3' }),
        Plot.text(rows.slice(-1), { x: 'date', y: 'y', text: () => 'Actual', dx: 8, textAnchor: 'start', fill: C.actual, fontWeight: 700, fontSize: 12, dy: -8 }),
        Plot.text(rows.slice(-1), { x: 'date', y: 'f', text: () => 'Forecast', dx: 8, textAnchor: 'start', fill: css('--accent-text'), fontWeight: 700, fontSize: 12, dy: 8 }),
        Plot.text([d[out.t0].date], { x: (v: any) => v, frameAnchor: 'top', dy: -10, dx: 4, textAnchor: 'start', text: () => 'Deployed Jan 2019', fill: C.muted, fontSize: 12 }),
        Plot.tip(rows, Plot.pointerX({ x: 'date', y: 'y', title: (r: any) => `${monYr(r.date)}\nActual: ${fmtShort(meta, r.y)} ${meta.unitAxis}\nOne-step forecast: ${fmtShort(meta, r.f)}\nTracking signal: ${r.ts.toFixed(1)}${r.alarm ? '\nALARM' + (r.retrained ? ': model re-fitted' : '') : ''}` })),
      ],
    });
    top.setAttribute('role', 'img'); top.setAttribute('aria-label', `Actual ${meta.label} against one-step forecasts since January 2019, with ${out.cur.alarms.length} alarms marked.`);
    topEl.replaceChildren(top);
    const lim = Math.max(thr + 2, ...rows.map((r) => Math.abs(r.ts)));
    const ts = Plot.plot({
      width: W, height: 170, marginLeft: 58, marginRight: 80, marginTop: 10, style: plotStyle(),
      x: { label: null }, y: { domain: [-lim, lim], grid: true, label: '↑ Tracking signal' },
      marks: [
        Plot.rectY([0], { x1: () => rows[0].date, x2: () => rows[rows.length - 1].date, y1: -thr, y2: thr, fill: C.good, fillOpacity: 0.06 }),
        Plot.ruleY([thr, -thr], { stroke: C.danger, strokeDasharray: '4,4', strokeWidth: 1.5 }),
        Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
        Plot.lineY(rows, { x: 'date', y: 'ts', stroke: C.text2, strokeWidth: 2, curve: 'step-after' }),
        Plot.dot(alarms, { x: 'date', y: 'ts', fill: C.danger, r: 4.5, symbol: (r: any) => (r.retrained ? 'triangle' : 'circle') }),
        Plot.text([thr, -thr], { x: () => rows[rows.length - 1].date, y: (v: any) => v, text: (v: any) => `${v > 0 ? '+' : '−'}${thr} limit`, dx: 8, textAnchor: 'start', fill: C.danger, fontSize: 12 }),
        Plot.tip(rows, Plot.pointerX({ x: 'date', y: 'ts', title: (r: any) => `${monYr(r.date)}\nTracking signal: ${r.ts.toFixed(2)}\nError: ${fmtShort(meta, r.e)} ${meta.unitAxis}` })),
      ],
    });
    ts.setAttribute('role', 'img'); ts.setAttribute('aria-label', `Tracking signal with limits at plus and minus ${thr}.`);
    tsEl.replaceChildren(ts);
  }

  $effect(() => { out; retrain; draw(); });
  onMount(() => { const a = watchLayout(topEl, draw); return a; });
  const first = $derived(out && out.cur.alarms.length ? monYr(d[out.cur.alarms[0]].date) : '—');
  const gain = $derived(out ? 1 - out.on.mae / out.off.mae : 0);
</script>

<Explorable title="A deployed forecast needs a smoke alarm" caption="A model fitted on data through December 2018 is put into production in January 2019. Each month it forecasts the next month, the actual arrives, and the <b>tracking signal</b> (running sum of errors divided by the average absolute error) is updated. When it crosses the limit, an alarm fires: the errors are piling up on one side, so the forecast is biased. With <b>re-fit on alarm</b> on, the parameters are re-estimated on all data to date (triangles); either way the counters restart after an alarm.">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Series">
      {#each OPTS as o, i}<button class:on={oi === i} aria-pressed={oi === i} onclick={() => (oi = i)}>{seriesById(o.id).label}</button>{/each}
    </div>
    <label class="sl">Alarm limit ±<input type="range" min="2" max="8" step="0.5" bind:value={thr} aria-label="Tracking signal limit" aria-valuetext={`plus or minus ${thr}`} /> <b>{thr}</b></label>
    <label class="tg"><input type="checkbox" bind:checked={retrain} /> Re-fit on alarm</label>
  {/snippet}
  {#snippet aside()}
    {#if out}
      <div class="rd">
        <div class="stat"><span class="stat-v">{out.cur.alarms.length}</span><span class="stat-l">alarms since Jan 2019 (first: {first})</span></div>
        <div class="stat"><span class="stat-v">{fmtShort(meta, out.cur.mae)}</span><span class="stat-l">average one-step miss, {meta.unitAxis}</span></div>
        <p class="cmp">Re-fitting on alarm {gain >= 0 ? 'cuts' : 'raises'} the average miss by <b>{Math.abs(gain * 100).toFixed(0)}%</b> ({fmtMiss(meta, out.off.mae)} without, {fmtMiss(meta, out.on.mae)} with).</p>
        <p class="hint">Model: {opt.model}, {meta.adj}. Drag the limit down to 2: alarms everywhere, most of them false. Push it to 8: you hear about 2020 late.</p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={topEl} class="c1"></div>
  <div bind:this={tsEl} class="c2"></div>
</Explorable>

<style>
  .c1 { min-height: 220px; } .c2 { min-height: 170px; }
  .tg { display: inline-flex; align-items: center; gap: .4rem; cursor: pointer; }
  .tg input { accent-color: var(--accent); }
  .rd { display: flex; flex-direction: column; gap: .9rem; font-size: .84rem; }
  .cmp { margin: 0; color: var(--text-2); }
  .hint { margin: 0; color: var(--muted); font-size: .78rem; }
</style>
