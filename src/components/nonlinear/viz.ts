// Chapter 5 custom chart type for code labs: viz_custom("nl-fan", date=, actual=, mean=, lo80=, hi80=, lo95=, hi95=, hist_date=, hist=, title=, subtitle=)
// Daily count forecasts with 80/95% prediction intervals, actual outcomes, and a coverage strip underneath.
import * as Plot from '@observablehq/plot';
import { registerViz } from '../../lib/viz/render';

const D = (s: string) => new Date(s + 'T00:00:00');
const fmt = (v: number) => Math.round(v).toLocaleString();

export function fanChart(el: HTMLElement, o: {
  width: number; css: (v: string) => string; date: string[]; actual: number[]; mean: number[];
  lo80?: number[]; hi80?: number[]; lo95?: number[]; hi95?: number[]; hist_date?: string[]; hist?: number[]; level?: '80' | '95' | 'both';
}) {
  const { css } = o;
  const level = o.level ?? 'both';
  const rows = o.date.map((d, i) => ({
    date: D(d), y: o.actual[i], mu: o.mean[i], lo80: o.lo80?.[i], hi80: o.hi80?.[i], lo95: o.lo95?.[i], hi95: o.hi95?.[i],
  }));
  const lo = level === '80' ? 'lo80' : 'lo95', hi = level === '80' ? 'hi80' : 'hi95';
  rows.forEach((r: any) => (r.inside = r.y >= r[lo] && r.y <= r[hi]));
  const hist = (o.hist_date ?? []).map((d, i) => ({ date: D(d), y: o.hist![i] }));
  const fc = css('--c-forecast'), act = css('--c-actual'), danger = css('--danger'), muted = css('--muted');
  const marks: any[] = [];
  if (hist.length) {
    marks.push(Plot.lineY(hist, { x: 'date', y: 'y', stroke: css('--c-history'), strokeWidth: 1.5 }));
    marks.push(Plot.ruleX([rows[0].date], { stroke: css('--border-strong'), strokeDasharray: '3,4' }));
    marks.push(Plot.text([rows[0].date], { x: (d: any) => d, frameAnchor: 'top', dx: 6, dy: 2, textAnchor: 'start', text: () => 'Forecast starts', fill: muted, fontSize: 12, fontWeight: 650 }));
  }
  if (level !== '80' && o.lo95) marks.push(Plot.areaY(rows, { x: 'date', y1: 'lo95', y2: 'hi95', fill: fc, fillOpacity: 0.14, curve: 'step' }));
  if (level !== '95' && o.lo80) marks.push(Plot.areaY(rows, { x: 'date', y1: 'lo80', y2: 'hi80', fill: fc, fillOpacity: 0.26, curve: 'step' }));
  marks.push(
    Plot.lineY(rows, { x: 'date', y: 'mu', stroke: fc, strokeWidth: 2, curve: 'step' }),
    Plot.dot(rows.filter((r: any) => r.inside), { x: 'date', y: 'y', r: 2.8, fill: act }),
    Plot.dot(rows.filter((r: any) => !r.inside), { x: 'date', y: 'y', r: 3.6, symbol: 'times', stroke: danger, strokeWidth: 1.8 }),
    Plot.tip(rows, Plot.pointerX({ x: 'date', y: 'y', title: (r: any) => `${r.date.toDateString().slice(4)}\nActual: ${fmt(r.y)} rentals\nForecast: ${fmt(r.mu)}${r.lo80 != null ? `\n80%: ${fmt(r.lo80)}–${fmt(r.hi80)}` : ''}${r.lo95 != null ? `\n95%: ${fmt(r.lo95)}–${fmt(r.hi95)}` : ''}` })),
  );
  const sandy = rows.find((r) => r.y < 100);
  if (sandy) marks.push(Plot.text([sandy], { x: 'date', y: 'y', text: () => 'Hurricane Sandy: system closed', dx: 8, textAnchor: 'start', fill: danger, fontSize: 12, fontWeight: 650, stroke: css('--surface'), strokeWidth: 3, paintOrder: 'stroke' }));
  const W = o.width;
  const chart = Plot.plot({
    width: W, height: Math.max(260, Math.min(380, W * 0.48)), marginLeft: 56, marginRight: 16, marginTop: 18, marginBottom: 30,
    style: { background: 'transparent', color: muted, fontSize: '12px', overflow: 'visible' },
    x: { label: null }, y: { grid: true, label: null, tickFormat: (d: number) => d.toLocaleString() }, marks,
  });
  // coverage strip: one cell per day, filled when the interval caught the actual value
  const strip = Plot.plot({
    width: W, height: 44, marginLeft: 56, marginRight: 16, marginTop: 4, marginBottom: 18,
    style: { background: 'transparent', color: muted, fontSize: '12px', overflow: 'visible' },
    x: { domain: [rows[0].date, rows[rows.length - 1].date], axis: null }, y: { axis: null, domain: [0, 1] },
    marks: [
      Plot.rectY(rows, { x1: 'date', x2: (r: any) => new Date(+r.date + 864e5), y1: 0.15, y2: 0.85, fill: (r: any) => (r.inside ? css('--good') : danger), fillOpacity: (r: any) => (r.inside ? 0.7 : 0.9), insetRight: 0.5 }),
      Plot.text([rows[0].date], { x: (d: any) => d, y: 0, dy: 12, textAnchor: 'start', text: () => `Coverage strip: green = inside the ${level === 'both' ? '95%' : level + '%'} interval, red = outside`, fill: muted, fontSize: 12 }),
    ],
  });
  const cov = rows.filter((r: any) => r.inside).length / rows.length;
  chart.setAttribute('aria-label', `Daily rental forecasts with prediction intervals; ${Math.round(100 * cov)} percent of actual values fall inside the ${level === 'both' ? '95%' : level + '%'} interval.`);
  const wrap = document.createElement('div'); wrap.append(chart, strip);
  return { node: wrap, coverage: cov };
}

registerViz('nl-fan', (spec, el, ctx) => {
  if (spec.title || spec.subtitle) {
    const h = document.createElement('div'); h.className = 'viz-head';
    if (spec.title) { const t = document.createElement('div'); t.className = 'viz-title'; t.textContent = spec.title; h.append(t); }
    if (spec.subtitle) { const t = document.createElement('div'); t.className = 'viz-sub'; t.textContent = spec.subtitle; h.append(t); }
    el.append(h);
  }
  const arr = (v: any) => (v == null ? undefined : ([] as any[]).concat(v));
  const { node } = fanChart(el, { width: ctx.width, css: ctx.css, date: arr(spec.date)!, actual: arr(spec.actual)!, mean: arr(spec.mean)!,
    lo80: arr(spec.lo80), hi80: arr(spec.hi80), lo95: arr(spec.lo95), hi95: arr(spec.hi95), hist_date: arr(spec.hist_date), hist: arr(spec.hist), level: 'both' });
  el.append(node);
  if (spec.source) { const f = document.createElement('div'); f.className = 'viz-source'; f.innerHTML = `<span>Source: ${spec.source}</span>`; el.append(f); }
});
