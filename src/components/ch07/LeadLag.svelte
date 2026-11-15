<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, type Pt } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { logDiff, between, ccf, zscore, key, ymLabel } from './lib';
  import './viz';

  // Lead-lag slider: slide an indicator in time against payroll job growth and watch the correlation.
  type Ind = { label: string; id: string; to?: 'month'; tf: 'yoy' | 'level'; invert: boolean; kind: string; unit: string };
  const IND: Record<'claims' | 'permits' | 'ip' | 'unrate', Ind> = {
    claims: { label: 'Initial claims', id: 'ICSA', to: 'month', tf: 'yoy', invert: true, kind: 'leading', unit: '% change from a year earlier' },
    permits: { label: 'Building permits', id: 'PERMIT', tf: 'yoy', invert: false, kind: 'leading', unit: '% change from a year earlier' },
    ip: { label: 'Industrial production', id: 'INDPRO', tf: 'yoy', invert: false, kind: 'coincident', unit: '% change from a year earlier' },
    unrate: { label: 'Unemployment rate', id: 'UNRATE', tf: 'level', invert: true, kind: 'lagging', unit: '% of labor force' },
  };
  type K = keyof typeof IND;
  let which: K = $state('claims');
  let k = $state(0);
  let covid = $state(false);
  let target: Pt[] = $state([]);
  let ind: Pt[] = $state([]);
  let rec: { a: Date; b: Date }[] = $state([]);
  let el: HTMLDivElement, elc: HTMLDivElement;
  const K_MIN = -18, K_MAX = 18;

  async function load() {
    const d = IND[which];
    const [p, x] = await Promise.all([loadSeries('PAYEMS'), loadSeries(d.id, d.to ? { to: d.to } : {})]);
    target = logDiff(p.data, 12);
    ind = d.tf === 'yoy' ? logDiff(x.data, 12) : x.data;
  }
  async function loadRec() {
    const u = await loadSeries('USREC', { start: '1985-01-01' });
    const out: { a: Date; b: Date }[] = [];
    let s: Date | null = null;
    u.data.forEach((p, i) => {
      if (p.value === 1 && !s) s = p.date;
      if ((p.value !== 1 || i === u.data.length - 1) && s) { out.push({ a: s, b: p.date }); s = null; }
    });
    rec = out;
  }

  // Align both series on the same months inside the chosen window (as R's window() + ccf() does).
  const aligned = $derived.by(() => {
    if (!target.length || !ind.length) return null;
    const end = covid ? '2099-12' : '2019-12';
    const T = between(target, '1990-01', end), X = new Map(between(ind, '1990-01', end).map((p) => [key(p.date), p.value]));
    const rows = T.filter((p) => X.has(key(p.date))).map((p) => ({ date: p.date, y: p.value, x: X.get(key(p.date))! }));
    return { rows, x: rows.map((r) => r.x), y: rows.map((r) => r.y) };
  });
  const curve = $derived.by(() => {
    if (!aligned) return [];
    return Array.from({ length: K_MAX - K_MIN + 1 }, (_, i) => { const lead = K_MIN + i; return { lead, r: ccf(aligned.x, aligned.y, -lead) }; });
  });
  const cur = $derived(curve.find((c) => c.lead === k)?.r ?? 0);
  const best = $derived(curve.length ? curve.reduce((a, b) => (Math.abs(b.r) > Math.abs(a.r) ? b : a)) : { lead: 0, r: 0 });

  function draw() {
    if (!el || !aligned) return;
    const d = IND[which];
    const zy = zscore(aligned.y), zx = zscore(aligned.x).map((v) => (d.invert ? -v : v));
    const shift = (dt: Date) => new Date(dt.getFullYear(), dt.getMonth() + k, 1);
    const Y = aligned.rows.map((r, i) => ({ date: r.date, v: zy[i], raw: r.y }));
    const Xs = aligned.rows.map((r, i) => ({ date: shift(r.date), orig: r.date, v: zx[i], raw: r.x }));
    const lo = Y[0].date, hi = Y[Y.length - 1].date;
    const W = el.clientWidth;
    const accent = getComputedStyle(el).getPropertyValue('--ch').trim() || C.s[3];
    const xLabel = `${d.label}${d.invert ? ', inverted' : ''}${k ? `, shifted ${Math.abs(k)} mo ${k > 0 ? 'later' : 'earlier'}` : ''}`;
    const chart = Plot.plot({
      width: W, height: Math.max(280, Math.min(380, W * 0.46)), marginLeft: 40, marginRight: 12, marginTop: 26,
      style: plotStyle(), x: { label: null, domain: [lo, hi] }, y: { grid: true, label: 'standard deviations from average', labelAnchor: 'top' as any },
      marks: [
        Plot.rectX(rec.filter((r) => r.b >= lo && r.a <= hi), { x1: 'a', x2: 'b', fill: C.muted, fillOpacity: 0.14 }),
        Plot.ruleY([0], { stroke: C.borderStrong }),
        Plot.lineY(Xs.filter((p) => p.date <= hi && p.date >= lo), { x: 'date', y: 'v', stroke: accent, strokeWidth: 2.2 }),
        Plot.lineY(Y, { x: 'date', y: 'v', stroke: C.history, strokeWidth: 2.2 }),
        Plot.text([Y[Y.length - 1]], { x: 'date', y: 'v', text: () => 'Job growth', textAnchor: 'end', dy: -12, fill: C.history, fontWeight: 650, fontSize: 12, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' } as any),
        Plot.text([Xs[0]], { x: () => lo, y: 'v', text: () => xLabel, frameAnchor: 'top-left', dx: 4, dy: -20, textAnchor: 'start', fill: accent, fontWeight: 650, fontSize: 12 } as any),
        Plot.tip(Xs.filter((p) => p.date <= hi && p.date >= lo), Plot.pointerX({ x: 'date', y: 'v', title: (p: any) => `${d.label} from ${ymLabel(p.orig)}: ${p.raw.toFixed(1)} (${d.unit})\nplotted at ${ymLabel(p.date)}` })),
      ],
    });
    el.replaceChildren(chart);

    const cc = Plot.plot({
      width: elc.clientWidth || 260, height: 150, marginLeft: 34, marginRight: 8, marginBottom: 30, style: { ...plotStyle(), fontSize: '12px' },
      x: { label: 'lead (months) →', ticks: [-18, -12, -6, 0, 6, 12, 18] }, y: { domain: [-1, 1], ticks: [-1, 0, 1], grid: true, label: null },
      marks: [
        Plot.ruleY([0], { stroke: C.borderStrong }),
        Plot.ruleX(curve, { x: 'lead', y1: 0, y2: 'r', stroke: (c: any) => (c.lead === k ? accent : C.s[0]), strokeWidth: (c: any) => (c.lead === k ? 4 : 2), strokeOpacity: (c: any) => (c.lead === k ? 1 : 0.55) }),
        Plot.dot([best], { x: 'lead', y: 'r', stroke: C.text, r: 4.5, fill: 'none' }),
      ],
    });
    cc.setAttribute('aria-label', `Cross-correlation by lead; strongest at a lead of ${best.lead} months`);
    elc.replaceChildren(cc);
  }

  $effect(() => { which; load(); });
  $effect(() => { aligned; k; rec; draw(); });
  onMount(() => { loadRec(); const a = watchLayout(el, draw); return a; });

  const sign = (v: number) => (v < 0 ? '−' : '') + Math.abs(v).toFixed(2);
  const desc = $derived(k > 0 ? `${d0().label} ${k} month${k > 1 ? 's' : ''} earlier vs. job growth now` : k < 0 ? `${d0().label} ${-k} month${k < -1 ? 's' : ''} later vs. job growth now` : `same month`);
  function d0() { return IND[which]; }
</script>

<Explorable title="Slide the indicator in time until it lines up with jobs" caption={`Both lines are standardized (0 = average, ±1 = one standard deviation) so you can compare shapes. Job growth is the 12-month % change in nonfarm payrolls. Positive leads mean the indicator is shifted <b>later</b>, so its past values are compared with job growth today. The circled bar on the right is the strongest correlation. Grey bands are NBER recessions. Data: FRED (PAYEMS, ${IND[which].id}, USREC), seasonally adjusted except the recession dates.`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Indicator">
      {#each Object.entries(IND) as [kk, d]}<button class:on={which === kk} onclick={() => { which = kk as K; }}>{d.label}</button>{/each}
    </div>
    <label class="sl">Lead <input type="range" min={K_MIN} max={K_MAX} step="1" bind:value={k} aria-label="Lead of the indicator in months" aria-valuetext={`${k} months`} /> <b>{k > 0 ? '+' : ''}{k} mo</b></label>
    <label class="chk"><input type="checkbox" bind:checked={covid} /> Include 2020 to today</label>
  {/snippet}
  {#snippet aside()}
    <div class="ro" aria-live="polite">
      <div class="stat"><span class="stat-v">r = {sign(cur)}</span><span class="stat-l">{desc}</span></div>
      <div bind:this={elc} class="cc"></div>
      <p class="best">Strongest: <b>{best.lead > 0 ? `${best.lead}-month lead` : best.lead < 0 ? `${-best.lead}-month lag` : 'same month'}</b>, r = {sign(best.r)}. {IND[which].label} behaves like a <b>{best.lead >= 5 ? 'leading' : best.lead <= -5 ? 'lagging' : 'roughly coincident'}</b> indicator here.</p>
      <button class="btn btn-ghost btn-sm" onclick={() => (k = best.lead)}>Snap to the best lead</button>
    </div>
  {/snippet}
  <div bind:this={el} class="chart" role="img" aria-label="Job growth and a shifted economic indicator, both standardized"></div>
</Explorable>

<style>
  .chart { min-height: 280px; }
  .ro { display: flex; flex-direction: column; gap: .6rem; font-size: .84rem; }
  .cc { min-height: 150px; }
  .best { margin: 0; color: var(--text-2); }
  .chk { display: inline-flex; align-items: center; gap: .4rem; cursor: pointer; }
  .chk input { accent-color: var(--accent); }
</style>
