// Chapter 2 custom chart types for code labs. Emit from R/Python with viz_custom("ch02-subseries", date=, value=, ...).
import * as Plot from '@observablehq/plot';
import { registerViz } from '../../lib/viz/render';

const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const fmt = (v: number) => (Math.abs(v) >= 1e4 ? v.toLocaleString(undefined, { maximumFractionDigits: 0 }) : +v.toPrecision(4) + '');

/** Seasonal subseries ("cycle") plot: for each month, a mini line of that month across years plus its mean. */
registerViz('ch02-subseries', (spec, el, ctx) => {
  if (spec.title || spec.subtitle) {
    const h = document.createElement('div'); h.className = 'viz-head';
    if (spec.title) { const t = document.createElement('div'); t.className = 'viz-title'; t.textContent = spec.title; h.append(t); }
    if (spec.subtitle) { const t = document.createElement('div'); t.className = 'viz-sub'; t.textContent = spec.subtitle; h.append(t); }
    el.append(h);
  }
  const dates: string[] = [].concat(spec.date), vals: number[] = [].concat(spec.value);
  const pts = dates.map((d, i) => { const dt = new Date(d + 'T00:00:00'); return { y: dt.getFullYear(), m: dt.getMonth(), v: vals[i] }; }).filter((p) => p.v != null && Number.isFinite(p.v));
  const y0 = Math.min(...pts.map((p) => p.y)), y1 = Math.max(...pts.map((p) => p.y));
  const span = Math.max(1, y1 - y0);
  // x position: month slot m in [m, m+0.8], years spread inside
  const rows = pts.map((p) => ({ ...p, x: p.m + 0.1 + (0.8 * (p.y - y0)) / span, month: MON[p.m] }));
  const means = MON.map((name, m) => { const v = rows.filter((r) => r.m === m).map((r) => r.v); return { m, name, mean: v.reduce((a, b) => a + b, 0) / v.length }; });
  const top = means.reduce((a, b) => (b.mean > a.mean ? b : a));
  const s1 = ctx.css('--c-s1'), act = ctx.css('--c-actual'), muted = ctx.css('--muted');
  const chart = Plot.plot({
    width: ctx.width, height: Math.max(260, Math.min(400, ctx.width * 0.48)), marginLeft: 64, marginRight: 16, marginTop: 16, marginBottom: 34,
    style: { background: 'transparent', color: muted, fontSize: '12px', overflow: 'visible' },
    x: { domain: [0, 12], ticks: MON.map((_, i) => i + 0.5), tickFormat: (d: number) => MON[Math.floor(d)], label: null, tickSize: 0 },
    y: { grid: true, nice: true, tickFormat: fmt, label: spec.ylab ?? null },
    marks: [
      Plot.ruleY(means, { y: 'mean', x1: (d: any) => d.m + 0.06, x2: (d: any) => d.m + 0.94, stroke: (d: any) => (d.m === top.m ? act : muted), strokeWidth: 2, strokeOpacity: 0.9 }),
      Plot.lineY(rows, { x: 'x', y: 'v', z: 'm', stroke: (d: any) => (d.m === top.m ? act : s1), strokeWidth: 2 }),
      Plot.dot(rows, { x: 'x', y: 'v', fill: (d: any) => (d.m === top.m ? act : s1), r: 1.8 }),
      Plot.tip(rows, Plot.pointer({ x: 'x', y: 'v', title: (d: any) => `${d.month} ${d.y}\n${fmt(d.v)}${spec.ylab ? ' ' + spec.ylab : ''}` })),
    ],
  });
  chart.setAttribute?.('aria-label', `Seasonal subseries plot. ${top.name} has the highest average.`);
  el.append(chart);
  const note = document.createElement('div'); note.className = 'viz-source';
  note.innerHTML = `<span>Each short line is one calendar month across ${y0}–${y1}; the flat bar is that month's average.${spec.source ? ' Source: ' + spec.source : ''}</span>`;
  el.append(note);
});
