<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, ym } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { fitETS, filter, conformalQ, qnorm, type Spec } from './models';
  import './viz';

  // Coverage audit: one-step forecasts from a model fitted on 2000–2009 with frozen parameters.
  // Every later month, does the truth land inside the interval? Normal formula vs rolling conformal.
  const SERIES = {
    RSXFSN: { label: 'Retail sales', long: 'U.S. retail sales excl. food services (RSXFSN, $ millions, NSA)', spec: { m: 12, trend: true, season: true } as Spec, to: undefined },
    ICSA: { label: 'Jobless claims', long: 'Initial jobless claims (ICSA, monthly average of weekly SA data)', spec: { m: 1, trend: false, season: false } as Spec, to: 'month' as const },
  };
  type SID = keyof typeof SERIES;
  const K = 36;
  let sid: SID = $state('RSXFSN');
  let method: 'normal' | 'conformal' = $state('normal');
  let level = $state(80);
  let base: { dates: Date[]; e: number[]; start: number } | null = $state.raw(null);
  let reveal = $state(1);
  let el: HTMLDivElement, el2: HTMLDivElement;
  let raf = 0;
  const reduce = () => typeof window !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches;

  async function load() {
    const cfg = SERIES[sid];
    const s = await loadSeries(sid, { start: '2000-01-01', to: cfg.to });
    const y = s.data.map((p) => Math.log(p.value));
    const start = s.data.findIndex((p) => p.date >= new Date('2010-01-01T00:00:00'));
    const fit = fitETS(y.slice(0, start), cfg.spec);
    const { resid } = filter(y, cfg.spec, fit.par);
    base = { dates: s.data.map((p) => p.date), e: resid, start };
    sweep();
  }
  function sweep() {
    cancelAnimationFrame(raf);
    if (reduce()) { reveal = 1; return; }
    const t0 = performance.now();
    const step = (t: number) => { reveal = Math.min(1, (t - t0) / 900); if (reveal < 1) raf = requestAnimationFrame(step); };
    reveal = 0; raf = requestAnimationFrame(step);
  }

  const audit = $derived.by(() => {
    if (!base) return null;
    const { e, dates, start } = base;
    const burn = SERIES[sid].spec.season ? 12 : 2;
    const a = 1 - level / 100, z = qnorm(1 - a / 2);
    const rows: { date: Date; err: number; hw: number; inside: boolean }[] = [];
    for (let t = start; t < e.length; t++) {
      let hw: number;
      if (method === 'normal') { const past = e.slice(burn, t); hw = z * Math.sqrt(past.reduce((s, x) => s + x * x, 0) / (past.length - 1)); }
      else hw = conformalQ(e.slice(t - K, t).map(Math.abs), a);
      rows.push({ date: dates[t], err: 100 * e[t], hw: 100 * hw, inside: Math.abs(e[t]) <= hw });
    }
    const cov = (f: (r: any) => boolean) => { const r = rows.filter(f); return r.length ? (100 * r.filter((x) => x.inside).length) / r.length : NaN; };
    const yr = (r: any) => r.date.getFullYear();
    const running = rows.map((r, i) => { const w = rows.slice(Math.max(0, i - 23), i + 1); return { date: r.date, c: (100 * w.filter((x) => x.inside).length) / w.length }; }).slice(23);
    return { rows, running, all: cov(() => true), eras: [['2010–2019', cov((r) => yr(r) < 2020)], ['2020–2021', cov((r) => yr(r) >= 2020 && yr(r) < 2022)], ['2022 on', cov((r) => yr(r) >= 2022)]] as [string, number][] };
  });

  function draw() {
    if (!el || !audit) return;
    const W = el.clientWidth;
    const n = Math.max(1, Math.round(audit.rows.length * reveal));
    const vis = audit.rows.slice(0, n);
    const abs = audit.rows.map((r) => Math.abs(r.err)).sort((a, b) => a - b);
    const lim = Math.max(abs[Math.floor(abs.length * 0.97)] * 1.6, ...audit.rows.map((r) => r.hw)) * 1.05;
    const off = audit.rows.filter((r) => Math.abs(r.err) > lim).length;
    const covid = audit.rows.find((r) => r.date.getFullYear() === 2020 && r.date.getMonth() === 3);
    el.replaceChildren(Plot.plot({
      width: W, height: Math.max(260, Math.min(340, W * 0.4)), marginLeft: 46, marginRight: 12, marginTop: 16, style: plotStyle(),
      x: { label: null }, y: { grid: true, label: '↑ One-month-ahead error (≈ % of forecast)', domain: [-lim, lim], clamp: true },
      symbol: { domain: [true, false], range: ['circle', 'times'] },
      marks: [
        Plot.areaY(audit.rows, { x: 'date', y1: (r: any) => -r.hw, y2: 'hw', fill: C.forecast, fillOpacity: 0.2, curve: 'step' }),
        Plot.ruleY([0], { stroke: C.borderStrong }),
        Plot.dot(vis, { x: 'date', y: 'err', symbol: 'inside', r: (r: any) => (r.inside ? 2.4 : 4), stroke: (r: any) => (r.inside ? C.good : C.danger), fill: (r: any) => (r.inside ? C.good : 'none'), strokeWidth: (r: any) => (r.inside ? 1 : 2) }),
        covid && reveal === 1 ? Plot.text([covid], { x: 'date', y: (r: any) => Math.max(-lim, Math.min(lim, r.err)), text: () => (Math.abs(covid.err) > lim ? 'April 2020 (off the chart)' : 'April 2020'), dx: 8, dy: covid.err < 0 ? 8 : -8, textAnchor: 'start', fill: C.text, fontSize: 12, fontWeight: 600, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }) : null,
        Plot.tip(audit.rows, Plot.pointerX({ x: 'date', y: (r: any) => Math.max(-lim, Math.min(lim, r.err)), title: (r: any) => `${ym(r.date)}\nError: ${r.err.toFixed(1)}%\nInterval: ±${r.hw.toFixed(1)}%\n${r.inside ? 'Inside' : 'MISS'}` })),
      ].filter(Boolean) as any,
    }));
    const runVis = audit.running.filter((r) => +r.date <= +vis[vis.length - 1].date);
    el2.replaceChildren(Plot.plot({
      width: W, height: 150, marginLeft: 46, marginRight: 70, marginTop: 10, style: plotStyle(),
      x: { label: null, domain: [audit.rows[0].date, audit.rows[audit.rows.length - 1].date] }, y: { grid: true, label: '↑ Coverage, last 24 months (%)', domain: [0, 100] },
      marks: [
        Plot.ruleY([level], { stroke: C.text2, strokeDasharray: '4,4', strokeWidth: 1.5 }),
        Plot.text([level], { x: audit.rows[audit.rows.length - 1].date, y: (d: any) => d, text: () => `promised ${level}%`, dx: 6, textAnchor: 'start', fill: C.text2, fontSize: 12 }),
        Plot.lineY(runVis, { x: 'date', y: 'c', stroke: method === 'normal' ? C.s[0] : C.s[2], strokeWidth: 2.4 }),
        Plot.tip(audit.running, Plot.pointerX({ x: 'date', y: 'c', title: (r: any) => `24 months to ${ym(r.date)}\n${r.c.toFixed(0)}% inside` })),
      ],
    }));
    offNote = off;
  }
  let offNote = $state(0);

  $effect(() => { sid; load(); });
  $effect(() => { method; sweep(); });
  $effect(() => { audit; reveal; draw(); });
  onMount(() => { const a = watchLayout(el, draw); return () => { a(); cancelAnimationFrame(raf); }; });
  const gap = (v: number) => (v - level >= 0 ? '+' : '') + (v - level).toFixed(1);
</script>

<Explorable title="Coverage audit: does an 80% interval contain the truth 80% of the time?"
  caption={`The model is fitted once on 2000–2009, then forecasts every later month one step ahead with its parameters frozen. Each dot is that month's forecast error; the violet band is the interval. <b>Normal formula</b>: ± z × σ, with σ re-estimated from all past errors. <b>Rolling conformal</b>: the band is set from the last ${K} errors (more in the conformal section below). Green circles landed inside; red crosses are misses. Errors are on the log scale, which is close to percent for small values; extreme months are pinned to the chart edge. Data: ${SERIES[sid].long}, from FRED.`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Series">
      {#each Object.entries(SERIES) as [k, d]}<button class:on={sid === k} onclick={() => (sid = k as SID)}>{d.label}</button>{/each}
    </div>
    <div class="seg" role="group" aria-label="Interval method">
      <button class:on={method === 'normal'} onclick={() => (method = 'normal')}>Normal formula</button>
      <button class:on={method === 'conformal'} onclick={() => (method = 'conformal')}>Rolling conformal</button>
    </div>
    <label class="sl">Promised level <input type="range" min="50" max="99" step="1" bind:value={level} aria-valuetext={`${level} percent`} /> <b>{level}%</b></label>
  {/snippet}
  {#snippet aside()}
    {#if audit}
      <div class="ro" aria-live="polite">
        <div class="stat"><span class="stat-v">{audit.all.toFixed(1)}%</span><span class="stat-l">of {audit.rows.length} months inside (promised {level}%)</span></div>
        <table>
          <thead><tr><th>Era</th><th>Inside</th><th>vs promise</th></tr></thead>
          <tbody>
            {#each audit.eras as [nm, v]}<tr><td>{nm}</td><td>{v.toFixed(0)}%</td><td class:bad={Math.abs(v - level) > 8}>{gap(v)}</td></tr>{/each}
          </tbody>
        </table>
        <p class="hint">Red marks an era more than 8 points off its promise. A good-looking total can hide bad eras. {offNote ? `${offNote} extreme month(s) sit beyond the chart edge.` : ''}</p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} class="chart" role="img" aria-label="One-month-ahead forecast errors with interval bands; misses marked with crosses"></div>
  <div bind:this={el2} role="img" aria-label="Rolling 24-month coverage compared with the promised level"></div>
</Explorable>

<style>
  .chart { min-height: 260px; }
  .ro { font-size: .84rem; color: var(--text-2); display: grid; gap: .6rem; }
  .ro table { font-size: .8rem; margin: 0; }
  .ro td, .ro th { padding: .3rem .35rem; font-variant-numeric: tabular-nums; }
  .ro td.bad { color: var(--danger); font-weight: 700; }
  .hint { color: var(--muted); font-size: .78rem; margin: 0; }
</style>
