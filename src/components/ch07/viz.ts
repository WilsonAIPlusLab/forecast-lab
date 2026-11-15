// Chapter 8 custom chart types, emitted from R/Python with viz_custom("ch07-…", …).
// Imported for its side effect by every ch07 Svelte component, so the types are registered on page load.
import * as Plot from '@observablehq/plot';
import { registerViz } from '../../lib/viz/render';

const fmt = (v: number) => (Math.abs(v) >= 1e4 ? v.toLocaleString(undefined, { maximumFractionDigits: 0 }) : +v.toPrecision(4) + '');
const arr = (v: any): number[] => ([] as any[]).concat(v ?? []).map(Number);

function head(el: HTMLElement, spec: any) {
  if (!spec.title && !spec.subtitle) return;
  const h = document.createElement('div'); h.className = 'viz-head';
  if (spec.title) { const t = document.createElement('div'); t.className = 'viz-title'; t.textContent = spec.title; h.append(t); }
  if (spec.subtitle) { const t = document.createElement('div'); t.className = 'viz-sub'; t.textContent = spec.subtitle; h.append(t); }
  el.append(h);
}
function source(el: HTMLElement, spec: any) {
  if (!spec.source) return;
  const f = document.createElement('div'); f.className = 'viz-source';
  f.innerHTML = `<span>Source: ${spec.source}</span>`;
  el.append(f);
}
const style = (ctx: any) => ({ background: 'transparent', color: ctx.css('--muted'), fontSize: '12px', overflow: 'visible' });

// ── cross-correlation lollipops, best lag highlighted ──────────
registerViz('ch07-ccf', (spec, el, ctx) => {
  head(el, spec);
  const lag = arr(spec.lag), val = arr(spec.value), ci = Number(spec.ci ?? 0), best = Number(spec.best);
  const d = lag.map((l, i) => ({ lag: l, v: val[i], best: l === best }));
  const hi = getComputedStyle(el).getPropertyValue('--ch').trim() || ctx.css('--c-s4');
  const chart = Plot.plot({
    width: ctx.width, height: 260, marginLeft: 48, marginRight: 16, marginBottom: 40, style: style(ctx),
    x: { label: spec.xlab ?? 'lag k', labelAnchor: 'center', labelArrow: 'none' as any },
    y: { label: 'correlation', grid: true, domain: [-1, 1] },
    marks: [
      ci ? Plot.rectY([0], { x1: lag[0] - 0.5, x2: lag[lag.length - 1] + 0.5, y1: -ci, y2: ci, fill: ctx.css('--muted'), fillOpacity: 0.12 }) : null,
      Plot.ruleY([0], { stroke: ctx.css('--border-strong'), strokeWidth: 1.5 }),
      Plot.ruleX([0], { stroke: ctx.css('--border-strong'), strokeDasharray: '4 4' }),
      Plot.ruleX(d, { x: 'lag', y1: 0, y2: 'v', stroke: (r: any) => (r.best ? hi : ctx.css('--c-s1')), strokeWidth: (r: any) => (r.best ? 3.5 : 2), strokeOpacity: (r: any) => (r.best ? 1 : 0.7) }),
      Plot.dot(d, { x: 'lag', y: 'v', fill: (r: any) => (r.best ? hi : ctx.css('--c-s1')), r: (r: any) => (r.best ? 5.5 : 3) }),
      Plot.text(d.filter((r) => r.best), { x: 'lag', y: 'v', text: (r: any) => `k = ${r.lag}: r = ${r.v.toFixed(2)}`, dy: (r: any) => (r.v < 0 ? 16 : -14), fill: ctx.css('--text'), fontWeight: 650, fontSize: 12, stroke: ctx.css('--surface'), strokeWidth: 3, paintOrder: 'stroke' } as any),
      Plot.tip(d, Plot.pointerX({ x: 'lag', y: 'v', title: (r: any) => `lag ${r.lag} months\ncorrelation ${r.v.toFixed(3)}` })),
    ].filter(Boolean) as any,
  });
  chart.setAttribute('aria-label', spec.title ?? 'Cross-correlation by lag');
  el.append(chart); source(el, spec);
});

// ── overlapping histograms of t-statistics (levels vs differences) ──
registerViz('ch07-hist', (spec, el, ctx) => {
  head(el, spec);
  const cut = Number(spec.cutoff ?? 2);
  const lim = 20;
  const clip = (v: number) => Math.max(-lim, Math.min(lim, v));
  const rows = [
    ...arr(spec.levels).map((v) => ({ v: clip(v), set: 'Levels (random walks)' })),
    ...arr(spec.differences).map((v) => ({ v: clip(v), set: 'Differences (white noise)' })),
  ];
  const col: Record<string, string> = { 'Levels (random walks)': ctx.css('--c-s2'), 'Differences (white noise)': ctx.css('--c-s1') };
  const lg = document.createElement('div'); lg.className = 'viz-legend';
  lg.innerHTML = Object.entries(col).map(([k, c]) => `<span><i style="background:${c};height:10px;opacity:.7"></i>${k}</span>`).join('') + `<span>values beyond ±${lim} piled at the edges</span>`;
  el.append(lg);
  const chart = Plot.plot({
    width: ctx.width, height: 280, marginLeft: 48, marginBottom: 40, style: style(ctx),
    x: { label: spec.xlab ?? 't-statistic', domain: [-lim, lim] }, y: { label: 'count', grid: true },
    marks: [
      Plot.rectX([0], { x1: -cut, x2: cut, fill: ctx.css('--good'), fillOpacity: 0.08 }),
      Plot.rectY(rows, Plot.binX({ y: 'count' }, { x: 'v', fill: (r: any) => col[r.set], fillOpacity: 0.65, mixBlendMode: 'normal', thresholds: 80, domain: [-lim, lim] } as any)),
      Plot.ruleX([-cut, cut], { stroke: ctx.css('--text-2'), strokeDasharray: '4 4', strokeWidth: 1.5 }),
      Plot.text([cut], { x: (d: number) => d, frameAnchor: 'top', dx: 6, dy: 4, textAnchor: 'start', text: () => `|t| = ${cut}`, fill: ctx.css('--text-2'), fontSize: 12 }),
      Plot.ruleY([0], { stroke: ctx.css('--border-strong') }),
    ],
  });
  chart.setAttribute('aria-label', spec.title ?? 'Histogram of t-statistics');
  el.append(chart); source(el, spec);
});

// ── dynamic multipliers: bars per month + running total ─────────
registerViz('ch07-multipliers', (spec, el, ctx) => {
  head(el, spec);
  const h = arr(spec.h), v = arr(spec.value), c = arr(spec.cumulative);
  const d = h.map((x, i) => ({ h: x, v: v[i], c: c[i] }));
  const lg = document.createElement('div'); lg.className = 'viz-legend';
  lg.innerHTML = `<span><i style="background:${ctx.css('--c-s2')};height:10px;opacity:.8"></i>Jobs added that month vs. normal</span><span><i style="border-top:2.5px solid ${ctx.css('--c-s1')}"></i>Running total (level of employment)</span>`;
  el.append(lg);
  const last = d[d.length - 1];
  const chart = Plot.plot({
    width: ctx.width, height: 300, marginLeft: 60, marginRight: 70, marginBottom: 40, style: style(ctx),
    x: { label: 'months after the jump in claims' }, y: { label: spec.ylab ?? null, grid: true, tickFormat: fmt },
    marks: [
      Plot.rectY(d, { x1: (r: any) => r.h - 0.38, x2: (r: any) => r.h + 0.38, y1: 0, y2: 'v', fill: ctx.css('--c-s2'), fillOpacity: 0.8 }),
      Plot.ruleY([0], { stroke: ctx.css('--border-strong'), strokeWidth: 1.5 }),
      Plot.lineY(d, { x: 'h', y: 'c', stroke: ctx.css('--c-s1'), strokeWidth: 2.5 }),
      Plot.dot([last], { x: 'h', y: 'c', fill: ctx.css('--c-s1'), r: 4 }),
      Plot.text([last], { x: 'h', y: 'c', text: (r: any) => `${fmt(r.c)}`, dx: 8, textAnchor: 'start', fill: ctx.css('--c-s1'), fontWeight: 650, fontSize: 12 }),
      Plot.tip(d, Plot.pointerX({ x: 'h', y: 'v', title: (r: any) => `month ${r.h}\nthat month: ${fmt(r.v)} thousand jobs\nrunning total: ${fmt(r.c)} thousand jobs` })),
    ],
  });
  chart.setAttribute('aria-label', spec.title ?? 'Dynamic multipliers');
  el.append(chart); source(el, spec);
});
