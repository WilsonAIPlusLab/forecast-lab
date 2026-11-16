<script lang="ts">
  // Explorable: read ADF and KPSS together. Each real series sits in one of four boxes, in levels or after one difference.
  // Test results are precomputed in R (src/labs/ch06/make_data.R -> urdata.json); the series itself is drawn live.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, ym, type Pt } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import UR from './urdata.json';

  type Res = { adf: number; kpss: number; nd: number; r1: number; sd: number; n: number };
  type S = { key: string; label: string; id: string; to?: string | null; start: string; end: string | null; tf: string; unit: string; dunit: string; level: Res; diff: Res };
  const SER = UR as unknown as S[];

  let key = $state('houst');
  let view: 'level' | 'diff' = $state('level');
  let raw: Pt[] = $state([]);
  let tsEl: HTMLDivElement, qEl: HTMLDivElement;

  const s = $derived(SER.find((x) => x.key === key)!);
  const res = $derived(s[view]);

  async function load() {
    const d = await loadSeries(s.id, { start: s.start, end: s.end ?? undefined, to: (s.to as any) ?? undefined });
    raw = d.data.map((p) => ({ date: p.date, value: s.tf === 'log' ? Math.log(p.value) : p.value }));
  }
  $effect(() => { key; load(); });
  const cur = $derived(view === 'level' ? raw : raw.slice(1).map((p, i) => ({ date: p.date, value: p.value - raw[i].value })));

  // test outcomes at 5%
  const adfRej = $derived(res.adf < 0.05), kpssRej = $derived(res.kpss < 0.05);
  const box = $derived(adfRej && !kpssRej ? 'stat' : !adfRej && kpssRej ? 'unit' : adfRej && kpssRej ? 'both' : 'none');
  const BOX = {
    stat: { t: 'Both say stationary', c: 'good', d: 'Stop differencing. Model the series as it is.' },
    unit: { t: 'Both say unit root', c: 'warn', d: 'Difference once, then test again.' },
    both: { t: 'The tests conflict', c: 'mixed', d: 'Each test rejects its own null. The series is very persistent; it may be stationary with shifts, or nearly a unit root. Use judgment and compare forecasts with and without the difference.' },
    none: { t: 'The data cannot tell', c: 'mixed', d: 'Neither test rejects. The sample is not informative enough; let economics and out-of-sample forecasts decide.' },
  } as const;
  const fp = (p: number, lo: number, hi: number) => (p <= lo + 1e-9 ? `≤ ${lo.toFixed(2)}` : p >= hi - 1e-9 ? `≥ ${hi.toFixed(2)}` : p.toFixed(p < 0.1 ? 3 : 2));
  const name = $derived(view === 'level' ? s.label : s.key === 'lpce' ? 'Monthly core inflation (log difference of prices)' : `Change in ${s.label.replace(' (log)', '')}${s.tf === 'log' ? ' (log difference)' : ''}`);
  const eq = (t: string) => (t.startsWith('≤') || t.startsWith('≥') ? t : `= ${t}`);
  const adfWords = $derived(adfRej ? `ADF p ${eq(fp(res.adf, 0.01, 0.99))}, below 0.05: reject "unit root". Evidence the series is stationary.` : `ADF p ${eq(fp(res.adf, 0.01, 0.99))}, above 0.05: cannot reject "unit root". (Not proof of one: ADF has low power.)`);
  const kpssWords = $derived(kpssRej ? `KPSS p ${eq(fp(res.kpss, 0.01, 0.10))}, below 0.05: reject "stationary". Evidence of a unit root.` : `KPSS p ${eq(fp(res.kpss, 0.01, 0.10))}, above 0.05: cannot reject "stationary".`);

  function drawTs() {
    if (!tsEl || !cur.length || tsEl.clientWidth < 120) return;
    const c = Plot.plot({
      width: tsEl.clientWidth, height: 220, marginLeft: 52, marginTop: 10, marginBottom: 28,
      style: plotStyle(), x: { label: null }, y: { label: null, grid: true, ticks: 5 },
      marks: [
        ...(view === 'diff' ? [Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 })] : []),
        Plot.lineY(cur, { x: 'date', y: 'value', stroke: view === 'diff' ? C.fitted : C.history, strokeWidth: view === 'diff' ? 1.4 : 2 }),
        Plot.tip(cur, Plot.pointerX({ x: 'date', y: 'value', title: (p: any) => `${ym(p.date)}\n${p.value.toFixed(4)} (${view === 'level' ? s.unit : s.dunit})` })),
      ],
    });
    c.setAttribute('aria-label', `${name}, monthly`);
    tsEl.replaceChildren(c);
  }

  function drawQ() {
    if (!qEl || qEl.clientWidth < 120) return;
    const W = qEl.clientWidth;
    // ADF p on the x-axis (log scale), KPSS p on the y-axis (log scale); both are capped by their look-up tables.
    const pts = SER.flatMap((x) => (['level', 'diff'] as const).map((st) => ({ k: x.key, st, adf: Math.max(0.01, x[st].adf), kpss: Math.min(0.1, Math.max(0.01, x[st].kpss)), sel: x.key === key && st === view, cur: x.key === key })));
    // jitter capped points so they don't sit on top of each other
    const seen = new Map<string, number>();
    for (const p of pts) { const id = `${p.adf.toFixed(3)}|${p.kpss.toFixed(3)}`; const n = seen.get(id) ?? 0; seen.set(id, n + 1); (p as any).jx = 1 + 0.12 * n; }
    const X = (p: any) => p.adf * p.jx;
    const lab = (x: number, y: number, t: string, a: 'start' | 'end') => Plot.text([{ x, y }], { x: 'x', y: 'y', text: () => t, textAnchor: a, fill: C.text2, fontSize: 12, fontWeight: 600 });
    const c = Plot.plot({
      width: W, height: 250, marginLeft: 50, marginRight: 14, marginTop: 14, marginBottom: 38,
      style: plotStyle(),
      x: { type: 'log', domain: [0.007, 1.4], label: 'ADF p-value (null: unit root) →', ticks: [0.01, 0.05, 0.2, 1], tickFormat: (d: number) => String(d) },
      y: { type: 'log', domain: [0.0085, 0.118], label: '↑ KPSS p-value (null: stationary)', ticks: [0.01, 0.05, 0.1], tickFormat: (d: number) => String(d) },
      marks: [
        // shaded boxes as areas (path elements), so a transient zero-width layout can never produce invalid rects
        Plot.areaY([{ x: 0.007 }, { x: 0.05 }], { x: 'x', y1: 0.05, y2: 0.118, fill: C.good, fillOpacity: 0.09 }),
        Plot.areaY([{ x: 0.05 }, { x: 1.4 }], { x: 'x', y1: 0.0085, y2: 0.05, fill: C.actual, fillOpacity: 0.1 }),
        Plot.ruleX([0.05], { stroke: C.borderStrong, strokeDasharray: '4 3' }),
        Plot.ruleY([0.05], { stroke: C.borderStrong, strokeDasharray: '4 3' }),
        lab(0.0078, 0.072, W < 420 ? 'Stationary' : 'Both say stationary', 'start'),
        lab(1.3, 0.022, W < 420 ? 'Unit root' : 'Both say unit root', 'end'),
        lab(0.0078, 0.022, 'Conflict', 'start'),
        lab(1.3, 0.072, 'Can’t tell', 'end'),
        Plot.dot(pts.filter((p) => !p.sel), { x: X, y: 'kpss', r: (p: any) => (p.cur ? 5 : 4), fill: (p: any) => (p.cur ? C.forecast : C.muted), fillOpacity: (p: any) => (p.cur ? 0.6 : 0.35), stroke: 'none' }),
        Plot.dot(pts.filter((p) => p.sel), { x: X, y: 'kpss', r: 8, fill: C.forecast, stroke: C.surface, strokeWidth: 2 }),
        Plot.tip(pts, Plot.pointer({ x: X, y: 'kpss', title: (p: any) => { const x = SER.find((q) => q.key === p.k)!; return `${x.label}${p.st === 'diff' ? ', after one difference' : ''}\nADF p ${fp(x[p.st as 'level' | 'diff'].adf, 0.01, 0.99)}, KPSS p ${fp(x[p.st as 'level' | 'diff'].kpss, 0.01, 0.1)}`; } })),
      ],
    });
    c.setAttribute('aria-label', `Verdict map. ${name}: ADF p ${fp(res.adf, 0.01, 0.99)}, KPSS p ${fp(res.kpss, 0.01, 0.1)}: ${BOX[box].t}.`);
    qEl.replaceChildren(c);
  }

  $effect(() => { cur; drawTs(); });
  $effect(() => { key; view; drawQ(); });
  onMount(() => { const a = watchLayout(tsEl, drawTs), b = watchLayout(qEl, drawQ); return () => { a(); b(); }; });
</script>

<Explorable title="Read the two tests together: which box is your series in?" caption="Six real U.S. series, monthly. The dots on the map are their ADF and KPSS p-values (computed in R with <code>adf.test()</code> and <code>kpss.test()</code>), in levels and after one difference; the large violet dot is the one selected. The two tests have <b>opposite nulls</b>, so the top-left box (ADF rejects, KPSS does not) means stationary and the bottom-right box means unit root. KPSS p-values are capped at 0.01 and 0.10 by its look-up table, so several dots share an edge; they are nudged sideways so you can see them.">
  {#snippet controls()}
    <label class="sel">Series
      <select bind:value={key} aria-label="Series">
        {#each SER as x}<option value={x.key}>{x.label}</option>{/each}
      </select>
    </label>
    <div class="seg" role="group" aria-label="Transformation">
      <button class:on={view === 'level'} aria-pressed={view === 'level'} onclick={() => (view = 'level')}>As it is</button>
      <button class:on={view === 'diff'} aria-pressed={view === 'diff'} onclick={() => (view = 'diff')}>After one difference</button>
    </div>
  {/snippet}
  <div class="pair">
    <div>
      <div class="nm">{name}</div>
      <div bind:this={tsEl} class="c"></div>
    </div>
    <div bind:this={qEl} class="c"></div>
  </div>
  <div class="read" aria-live="polite">
    <p class="box {BOX[box].c}"><b>{BOX[box].t}.</b> {BOX[box].d}</p>
    <ul>
      <li>{adfWords}</li>
      <li>{kpssWords}</li>
      <li>Lag-1 autocorrelation {res.r1.toFixed(2)}{res.r1 > 0.9 ? ': close to 1, the look of a trend' : res.r1 < -0.4 ? ': strongly negative, a hint of over-differencing' : ''}. <code>ndiffs()</code> asks for {res.nd} more difference{res.nd === 1 ? '' : 's'}.</li>
    </ul>
  </div>
</Explorable>

<style>
  .pair { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 1.2rem; }
  @media (max-width: 760px) { .pair { grid-template-columns: 1fr; } }
  .c { min-height: 220px; }
  .nm { font: 600 .86rem var(--font-ui); color: var(--text); margin-bottom: .3rem; }
  .sel { display: inline-flex; align-items: center; gap: .5rem; }
  .sel select { font: 600 .82rem var(--font-ui); background: var(--bg); color: var(--text); border: 1px solid var(--border); border-radius: 8px; padding: .32rem .5rem; max-width: 100%; }
  .read { margin-top: .6rem; font-size: .88rem; color: var(--text-2); }
  .read ul { margin: .4rem 0 0; padding-left: 1.1rem; }
  .read li { margin: .2rem 0; }
  .box { margin: 0; padding: .55rem .8rem; border-radius: 8px; border: 1px solid var(--border); color: var(--text); }
  .box.good { border-color: color-mix(in srgb, var(--good) 55%, transparent); }
  .box.warn { border-color: color-mix(in srgb, var(--c-actual) 55%, transparent); }
  .box.mixed { border-color: color-mix(in srgb, var(--c-forecast) 55%, transparent); }
</style>
