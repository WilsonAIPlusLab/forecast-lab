// Chapter 14 custom chart for code labs: nowcast vs outcome scatter with the 45-degree "perfect nowcast" line.
// Emit from R:  viz_custom("ch13-scatter45", x = , y = , labels = , xlab = , ylab = , title = , source = )
import * as Plot from '@observablehq/plot';
import { registerViz } from '../../lib/viz/render';

const fmt = (v: number) => (Math.abs(v) >= 100 ? v.toFixed(0) : v.toFixed(1));
const qLabel = (s: string) => { const m = +s.slice(5, 7); return `${s.slice(0, 4)} Q${Math.floor((m - 1) / 3) + 1}`; };

registerViz('ch13-scatter45', (spec, el, ctx) => {
  const xs: number[] = [].concat(spec.x), ys: number[] = [].concat(spec.y), labs: string[] = [].concat(spec.labels ?? []);
  const d = xs.map((x, i) => ({ x, y: ys[i], lab: labs[i] ? qLabel(labs[i]) : '', err: ys[i] - x })).filter((r) => Number.isFinite(r.x) && Number.isFinite(r.y));
  if (spec.title || spec.subtitle) {
    const h = document.createElement('div'); h.className = 'viz-head';
    if (spec.title) { const t = document.createElement('div'); t.className = 'viz-title'; t.textContent = spec.title; h.append(t); }
    if (spec.subtitle) { const t = document.createElement('div'); t.className = 'viz-sub'; t.textContent = spec.subtitle; h.append(t); }
    el.append(h);
  }
  const lo = Math.min(...d.map((r) => Math.min(r.x, r.y))), hi = Math.max(...d.map((r) => Math.max(r.x, r.y)));
  const pad = (hi - lo) * 0.05;
  const dom = [lo - pad, hi + pad];
  const big = d.slice().sort((a, b) => Math.abs(b.err) - Math.abs(a.err)).slice(0, 4);
  const W = Math.min(ctx.width, 620);
  const chart = Plot.plot({
    width: W, height: W * 0.82, marginLeft: 52, marginBottom: 42, marginRight: 20,
    style: { background: 'transparent', color: ctx.css('--muted'), fontSize: '12px', overflow: 'visible' },
    x: { domain: dom, label: spec.xlab ?? 'nowcast', grid: true, tickFormat: fmt },
    y: { domain: dom, label: spec.ylab ?? 'actual', grid: true, tickFormat: fmt },
    marks: [
      Plot.ruleY([0], { stroke: ctx.css('--border-strong') }), Plot.ruleX([0], { stroke: ctx.css('--border-strong') }),
      Plot.line([[dom[0], dom[0]], [dom[1], dom[1]]], { stroke: ctx.css('--c-actual'), strokeWidth: 2, strokeDasharray: '4 4' }),
      Plot.text([[dom[1], dom[1]]], { text: () => 'perfect nowcast', textAnchor: 'end', dx: -4, dy: -8, fill: ctx.css('--c-actual'), fontSize: 12 }),
      Plot.dot(d, { x: 'x', y: 'y', r: 4, fill: ctx.css('--c-forecast'), fillOpacity: 0.7, stroke: ctx.css('--surface'), strokeWidth: 1 }),
      Plot.text(big, { x: 'x', y: 'y', text: 'lab', dx: 8, textAnchor: 'start', fill: ctx.css('--text-2'), fontSize: 12, stroke: ctx.css('--surface'), strokeWidth: 3, paintOrder: 'stroke' } as any),
      Plot.tip(d, Plot.pointer({ x: 'x', y: 'y', title: (r: any) => `${r.lab}\nNowcast: ${r.x.toFixed(1)}%\nActual: ${r.y.toFixed(1)}%\nMiss: ${r.err >= 0 ? '+' : ''}${r.err.toFixed(1)} pts` })),
    ],
  });
  chart.setAttribute?.('aria-label', spec.title ?? 'Nowcast versus actual scatter');
  el.append(chart);
  if (spec.source) { const f = document.createElement('div'); f.className = 'viz-source'; f.innerHTML = `<span>Source: ${spec.source}</span>`; el.append(f); }
});
