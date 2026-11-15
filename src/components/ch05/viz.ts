// Chapter 6 custom chart type, emitted from R/Python with viz_custom("ch05-multiples", panels = …).
// A grid of small multiples: one panel per series with history, forecast, 80% band and a traffic-light badge.
import * as Plot from '@observablehq/plot';
import { registerViz } from '../../lib/viz/render';

export const status = (m: number) => (m > 1 ? { k: 'review', label: 'Review' } : m > 0.8 ? { k: 'watch', label: 'Watch' } : { k: 'ok', label: 'OK' });
const D = (s: string) => new Date(s + 'T00:00:00');
const fmtK = (v: number) => (Math.abs(v) >= 1000 ? `${Math.round(v / 1000)}k` : `${Math.round(v)}`);

registerViz('ch05-multiples', (spec, el, ctx) => {
  const css = ctx.css;
  if (spec.title) {
    const h = document.createElement('div'); h.className = 'viz-head';
    h.innerHTML = `<div class="viz-title"></div><div class="viz-sub">Sorted worst first by backtest MASE. Shaded band: 80% prediction interval. $ millions, not seasonally adjusted.</div>`;
    (h.firstChild as HTMLElement).textContent = spec.title;
    el.append(h);
  }
  const panels = [...spec.panels].sort((a: any, b: any) => b.mase - a.mase);
  const cols = ctx.width < 520 ? 2 : ctx.width < 820 ? 3 : 4;
  const w = Math.floor((ctx.width - (cols - 1) * 10) / cols);
  const grid = document.createElement('div');
  grid.style.cssText = `display:grid;grid-template-columns:repeat(${cols},1fr);gap:10px;`;
  const tone: Record<string, string> = { ok: css('--good'), watch: css('--warm'), review: css('--danger') };
  for (const p of panels) {
    const st = status(p.mase);
    const hist = p.date.map((d: string, i: number) => ({ date: D(d), v: p.value[i] }));
    const fc = p.fdate.map((d: string, i: number) => ({ date: D(d), v: p.mean[i], lo: p.lo[i], hi: p.hi[i] }));
    const cell = document.createElement('div');
    cell.style.cssText = `border:1px solid ${css('--border')};border-radius:8px;padding:6px 8px 2px;`;
    cell.innerHTML = `<div style="display:flex;justify-content:space-between;gap:6px;align-items:baseline;font-size:12px;line-height:1.3">
      <b style="color:${css('--text')};font-weight:600;overflow:hidden;text-overflow:ellipsis;white-space:nowrap"></b>
      <span style="flex:none;font-weight:700;color:${tone[st.k]}">${st.label} · ${p.mase.toFixed(2)}</span></div>
      <div style="font-size:12px;color:${css('--muted')}">${p.model}</div>`;
    (cell.querySelector('b') as HTMLElement).textContent = p.name;
    cell.append(Plot.plot({
      width: w - 16, height: 92, marginLeft: 34, marginRight: 4, marginTop: 6, marginBottom: 18,
      style: { background: 'transparent', color: css('--muted'), fontSize: '12px', overflow: 'visible' },
      x: { ticks: 2, label: null, tickFormat: (d: Date) => `’${String(d.getFullYear()).slice(2)}` },
      y: { ticks: 3, label: null, tickFormat: fmtK, grid: true, nice: true },
      marks: [
        Plot.areaY(fc, { x: 'date', y1: 'lo', y2: 'hi', fill: css('--c-forecast'), fillOpacity: 0.22 }),
        Plot.lineY(hist, { x: 'date', y: 'v', stroke: css('--c-history'), strokeWidth: 1.5 }),
        Plot.lineY(fc, { x: 'date', y: 'v', stroke: css('--c-forecast'), strokeWidth: 2 }),
      ],
    }) as any);
    cell.setAttribute('aria-label', `${p.name}: ${p.model}, backtest MASE ${p.mase.toFixed(2)}, status ${st.label}`);
    grid.append(cell);
  }
  el.append(grid);
  if (spec.source) { const f = document.createElement('div'); f.className = 'viz-source'; f.innerHTML = `<span>Source: ${spec.source}</span>`; el.append(f); }
});
