// Chapter 13: registers the "waterfall" chart type emitted by viz_custom("waterfall", ...) in Lab 13.3.
// Spec: { start, start_label, base, labels[], values[], feature_values[], total_label, unit, title, subtitle }
// All values are changes from `start` (last month's sales), in `unit`. Bars are drawn in change space,
// so the axis starts at zero = last month's level.
import * as Plot from '@observablehq/plot';
import { registerViz } from '../../lib/viz/render';

const money = (v: number, unit = '$bn') => `${v < 0 ? '−' : '+'}$${Math.abs(v).toFixed(1)}${unit.replace('$', '')}`;

registerViz('waterfall', (spec, el, ctx) => {
  const css = ctx.css;
  if (spec.title || spec.subtitle) {
    const h = document.createElement('div'); h.className = 'viz-head';
    if (spec.title) { const t = document.createElement('div'); t.className = 'viz-title'; t.textContent = spec.title; h.append(t); }
    if (spec.subtitle) { const t = document.createElement('div'); t.className = 'viz-sub'; t.textContent = spec.subtitle; h.append(t); }
    el.append(h);
  }
  const unit = spec.unit ?? '$bn';
  const items = [{ label: 'Base value (an average month)', value: +spec.base }, ...spec.labels.map((l: string, i: number) => ({ label: l, value: +spec.values[i] }))];
  let cum = 0;
  const rows = items.map((it) => { const r = { ...it, x1: cum, x2: cum + it.value }; cum += it.value; return r; });
  const total = { label: `${spec.total_label ?? 'Forecast'}: $${(spec.start + cum).toFixed(1)}bn`, value: cum, x1: 0, x2: cum, total: true };
  const all = [...rows, total];
  const order = all.map((r) => r.label);
  const pos = css('--c-s2'), neg = css('--c-s1');
  const chart = Plot.plot({
    width: ctx.width, height: 46 + all.length * 30, marginLeft: Math.min(250, 12 + 6.8 * Math.max(...order.map((s) => s.length))), marginRight: 70,
    style: { background: 'transparent', color: css('--muted'), fontSize: '12px' },
    x: { label: `Change from last month's sales ($${(+spec.start).toFixed(1)}bn), ${unit}`, grid: true, tickFormat: (v: number) => (v === 0 ? '0' : money(v, unit)) },
    y: { domain: order, label: null },
    marks: [
      Plot.ruleX([0], { stroke: css('--border-strong'), strokeWidth: 1.5 }),
      Plot.barX(all, { y: 'label', x1: 'x1', x2: 'x2', fill: (r: any) => (r.total ? css('--c-forecast') : r.value >= 0 ? pos : neg), insetTop: 5, insetBottom: 5, rx: 3 }),
      Plot.text(all, { y: 'label', x: (r: any) => Math.max(r.x1, r.x2), text: (r: any) => money(r.value, unit), dx: 6, textAnchor: 'start', fill: css('--text-2'), fontSize: 12 }),
      Plot.tickX(rows.slice(0, -1), { y: (_: any, i: number) => order[i + 1], x: 'x2', stroke: css('--border-strong'), strokeDasharray: '2,3' }),
    ],
  });
  chart.setAttribute('role', 'img');
  chart.setAttribute('aria-label', `Waterfall: from last month's $${(+spec.start).toFixed(1)}bn to a forecast of $${(spec.start + cum).toFixed(1)}bn`);
  el.append(chart);
  const note = document.createElement('div'); note.className = 'viz-source';
  note.textContent = 'Red bars push the forecast up, blue bars pull it down. Source: FRED (RSXFSN, UMCSENT, UNRATE); SHAP values from XGBoost.';
  el.append(note);
});
