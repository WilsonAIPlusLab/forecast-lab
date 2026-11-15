<script lang="ts">
  // STL explorer: exact STL (port of R's stl) on log retail sales; drag the seasonal and trend windows, toggle robustness.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, ym, type Series } from '../../lib/ts';
  import { C, watchLayout } from '../../lib/viz/theme';
  import { stl, seasonalStrength } from './stl';

  const S_OPTS: (number | 'periodic')[] = [5, 7, 9, 11, 13, 15, 19, 25, 35, 51, 'periodic'];
  let s: Series | null = $state(null);
  let sIdx = $state(4); // 13
  let tWin = $state(21);
  let tAuto = $state(true);
  let robust = $state(true);
  let el: HTMLDivElement;
  let mini: HTMLDivElement | undefined = $state();

  const nextOdd = (x: number) => { const r = Math.round(x); return r % 2 === 0 ? r + 1 : r; };
  const sWin = $derived(S_OPTS[sIdx]);
  const autoT = $derived(nextOdd(Math.ceil((1.5 * 12) / (1 - 1.5 / (sWin === 'periodic' ? 10 * ((s as Series | null)?.data.length ?? 261) + 1 : sWin)))));
  $effect(() => { if (tAuto) tWin = autoT; });

  onMount(async () => { s = await loadSeries('RSXFSN', { start: '2005-01-01' }); });

  const fit = $derived.by(() => {
    if (!s) return null;
    const y = s.data.map((p) => Math.log(p.value));
    const f = stl(y, { period: 12, sWindow: sWin, tWindow: tWin, robust });
    const pc = (v: number) => 100 * (Math.exp(v) - 1);
    const rows = s.data.map((p, i) => ({ date: p.date, value: p.value / 1000, trend: Math.exp(f.trend[i]) / 1000, S: pc(f.seasonal[i]), R: pc(f.remainder[i]), w: f.weights[i], m: p.date.getMonth(), yr: p.date.getFullYear() }));
    const at = (yy: number, mm: number) => rows.find((r) => r.yr === yy && r.m === mm);
    const decR = rows.filter((r) => r.m === 11);
    const mean = (a: number[]) => a.reduce((x, y) => x + y, 0) / a.length;
    const lastDec = decR[decR.length - 1];
    return {
      rows, decR, fs: seasonalStrength(f.seasonal, f.remainder),
      apr20: at(2020, 3)?.R ?? NaN, decS: lastDec ? at(lastDec.yr, 11)!.S : NaN, decYear: lastDec?.yr,
      early: mean(decR.filter((r) => r.yr <= 2009).map((r) => r.R)), late: mean(decR.filter((r) => r.yr >= lastDec.yr - 4).map((r) => r.R)),
      down: rows.filter((r) => r.w < 0.3).length,
    };
  });

  const covid = [{ a: new Date('2020-03-01T00:00:00'), b: new Date('2021-06-01T00:00:00') }];
  const style = () => ({ background: 'transparent', color: C.muted, fontSize: '12px', fontFamily: 'var(--font-ui)', overflow: 'visible' as const });
  const f1 = (v: number) => (v > 0 ? '+' : v < 0 ? '−' : '') + Math.abs(v).toFixed(1) + '%';

  function draw() {
    if (!el || !fit) return;
    const W = el.clientWidth, rows = fit.rows;
    const common = { width: W, marginLeft: 58, marginRight: 14, style: style() };
    const band = Plot.rectX(covid, { x1: 'a', x2: 'b', fill: C.danger, fillOpacity: 0.08 });
    const p1 = Plot.plot({
      ...common, height: 190, marginTop: 18, marginBottom: 6, x: { axis: null }, y: { grid: true, ticks: 4, label: '$bn per month', tickFormat: (d: number) => `$${d}` },
      marks: [band,
        Plot.lineY(rows, { x: 'date', y: 'value', stroke: C.history, strokeWidth: 1.25, strokeOpacity: 0.5 }),
        Plot.lineY(rows, { x: 'date', y: 'trend', stroke: C.s[0], strokeWidth: 2.6 }),
        Plot.text([rows[rows.length - 1]], { x: 'date', y: 'trend', text: () => 'trend', dx: -4, dy: 14, textAnchor: 'end', fill: C.s[0], fontWeight: 700, fontSize: 12 }),
        Plot.text([covid[0]], { x: 'a', frameAnchor: 'top', dy: -12, text: () => 'COVID', textAnchor: 'start', fill: C.danger, fontSize: 12, fontWeight: 650 }),
        Plot.tip(rows, Plot.pointerX({ x: 'date', y: 'value', title: (r: any) => `${ym(r.date)}\nSales: $${r.value.toFixed(1)}bn\nTrend: $${r.trend.toFixed(1)}bn` }))],
    });
    const p2 = Plot.plot({
      ...common, height: 130, marginTop: 14, marginBottom: 6, x: { axis: null }, y: { grid: true, ticks: 4, label: 'seasonal, %', tickFormat: (d: number) => `${d > 0 ? '+' : ''}${d}` },
      marks: [band, Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
        Plot.lineY(rows, { x: 'date', y: 'S', stroke: C.s[2], strokeWidth: 1.8 }),
        Plot.tip(rows, Plot.pointerX({ x: 'date', y: 'S', title: (r: any) => `${ym(r.date)}\nSeasonal: ${f1(r.S)} vs trend` }))],
    });
    const p3 = Plot.plot({
      ...common, height: 150, marginTop: 14, marginBottom: 28, x: { label: null }, y: { grid: true, ticks: 4, label: 'remainder, %', tickFormat: (d: number) => `${d > 0 ? '+' : ''}${d}` },
      marks: [band, Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
        Plot.ruleX(rows, { x: 'date', y1: 0, y2: 'R', stroke: (r: any) => (r.m === 11 ? C.actual : C.s[1]), strokeWidth: (r: any) => (r.m === 11 ? 2 : 1.5), strokeOpacity: 0.85 }),
        robust ? Plot.dot(rows.filter((r) => r.w < 0.3), { x: 'date', y: 'R', r: 3.5, stroke: C.text, fill: 'none', strokeWidth: 1.3 }) : null,
        Plot.tip(rows, Plot.pointerX({ x: 'date', y: 'R', title: (r: any) => `${ym(r.date)}\nRemainder: ${f1(r.R)}${robust ? `\nRobustness weight: ${r.w.toFixed(2)}` : ''}` }))].filter(Boolean) as any,
    });
    for (const [p, lab] of [[p1, 'Retail sales and STL trend'], [p2, 'Seasonal component in percent'], [p3, 'Remainder component in percent; December bars in gold']] as const) p.setAttribute('aria-label', lab);
    el.replaceChildren(p1, p2, p3);
    if (mini) {
      const m = Plot.plot({
        width: mini.clientWidth || 240, height: 120, marginLeft: 34, marginRight: 6, marginTop: 8, marginBottom: 22, style: style(),
        x: { tickFormat: (d: number) => (d % 5 === 0 ? String(d) : ''), tickSize: 0, label: null }, y: { grid: true, ticks: 3, label: '%', tickFormat: (d: number) => `${d > 0 ? '+' : d < 0 ? '−' : ''}${Math.abs(d)}` },
        marks: [Plot.ruleY([0], { stroke: C.borderStrong }), Plot.barY(fit.decR, { x: 'yr', y: 'R', fill: C.actual, fillOpacity: 0.85 }),
          Plot.linearRegressionY(fit.decR, { x: 'yr', y: 'R', stroke: C.text, strokeWidth: 1.5, ci: 0 })],
      });
      m.setAttribute('aria-label', 'December remainders by year, with a fitted trend line');
      mini.replaceChildren(m);
    }
  }
  $effect(() => { fit; draw(); });
  onMount(() => watchLayout(el, draw));
</script>

<Explorable title="Too flexible, too rigid, or just right?" caption="Drag the <b>seasonal window</b> (how many years each month's effect is averaged over) and the <b>trend window</b> (how many months the trend is smoothed over). Gold bars are Decembers. Circled points are months the <b>robust</b> fit treats as outliers. This is exact STL, the same algorithm and defaults as R's <code>stl()</code>, run on log retail sales (NSA) from 2005, with components shown in percent.">
  {#snippet controls()}
    <label class="sl">Seasonal window <input type="range" min="0" max={S_OPTS.length - 1} step="1" bind:value={sIdx} aria-label="Seasonal window, s.window" aria-valuetext={sWin === 'periodic' ? 'periodic: the same pattern every year' : `${sWin} years`} /> <b>{sWin === 'periodic' ? 'periodic' : `${sWin} yrs`}</b></label>
    <label class="sl">Trend window <input type="range" min="7" max="61" step="2" value={tWin} oninput={(e) => { tAuto = false; tWin = +(e.currentTarget as HTMLInputElement).value; }} aria-label="Trend window, t.window" aria-valuetext={`${tWin} months`} /> <b>{tWin} mo</b>{#if !tAuto}<button class="reset" onclick={() => (tAuto = true)}>auto</button>{/if}</label>
    <label class="chk"><input type="checkbox" bind:checked={robust} /> Robust (down-weight outliers)</label>
  {/snippet}
  {#snippet aside()}
    {#if fit}
      <div class="ro">
        <div class="stat"><span class="stat-v">{f1(fit.apr20)}</span><span class="stat-l">remainder in April 2020: how much of the lockdown collapse STL calls "unusual"</span></div>
        <div class="stat"><span class="stat-v">{f1(fit.decS)}</span><span class="stat-l">December {fit.decYear} seasonal effect</span></div>
        <div class="leak">
          <div class="lk-h">Leakage check: December remainders</div>
          <div bind:this={mini}></div>
          <p class="lk-t">Avg {f1(fit.early)} in 2005–09 vs {f1(fit.late)} in the last five Decembers. {Math.abs(fit.early - fit.late) > 2.5 ? 'A slope here means the seasonal pattern changed but the model could not follow: seasonality is leaking into the remainder.' : 'No strong slope: the seasonal layer keeps up with the changing December.'}</p>
        </div>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart" aria-label="STL decomposition of U.S. retail sales in three panels"></div>
</Explorable>

<style>
  .chart { min-height: 470px; }
  .ro { display: grid; gap: .9rem; font-size: .82rem; }
  .stat-l { line-height: 1.4; }
  .leak { border-top: 1px solid var(--border); padding-top: .7rem; }
  .lk-h { font-weight: 650; color: var(--text); margin-bottom: .2rem; }
  .lk-t { color: var(--text-2); margin: .3rem 0 0; line-height: 1.45; }
  .chk { display: inline-flex; gap: .45rem; align-items: center; cursor: pointer; }
  .chk input { accent-color: var(--accent); width: 16px; height: 16px; }
  .reset { all: unset; cursor: pointer; font-size: .74rem; color: var(--accent-text); border: 1px solid var(--border); border-radius: 6px; padding: .1rem .4rem; }
  .reset:focus-visible { outline: 2px solid var(--accent-2); }
</style>
