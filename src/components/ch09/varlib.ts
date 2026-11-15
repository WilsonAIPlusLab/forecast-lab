// Chapter 10 shared helpers: precomputed VAR results (from build_data.R), variable metadata,
// and two custom chart types for the labs ("ch09-irf", "ch09-fevd").
import * as Plot from '@observablehq/plot';
import raw from './var_data.json';
import { registerViz } from '../../lib/viz/render';
import { C } from '../../lib/viz/theme';

export type VarKey = 'infl' | 'unemp' | 'ffr' | 'spread';
export interface Band { pt: number[]; lo: number[]; hi: number[] }
export interface VarData {
  meta: { sample: string; p: number; h: number; runs: number; ci: number; n: number; resid_cor: number[][]; vars: VarKey[] };
  irf: Record<string, Record<string, Record<string, Band>>>;
  fevd: Record<string, Record<string, Record<string, number[]>>>;
  granger: Record<string, Record<string, { from: VarKey; to: VarKey; F: number; p: number }[]>>;
}
export const D = raw as unknown as VarData;

/** Colour slot per variable, consistent across every Chapter 10 figure (never the only cue: always labelled). */
const SLOT: Record<VarKey, number> = { infl: 1, unemp: 0, ffr: 2, spread: 5 };
export const col = (k: string) => C.s[SLOT[k as VarKey] ?? 4];
export const META: Record<VarKey, { label: string; short: string; unit: string; noun: string }> = {
  infl: { label: 'Inflation', short: 'Inflation', unit: 'pp', noun: 'inflation (CPI, % annualized)' },
  unemp: { label: 'Unemployment', short: 'Unemp.', unit: 'pp', noun: 'the unemployment rate (%)' },
  ffr: { label: 'Fed funds rate', short: 'Fed funds', unit: 'pp', noun: 'the federal funds rate (%)' },
  spread: { label: 'Term spread', short: 'Spread', unit: 'pp', noun: 'the 10y–3m Treasury spread (pp)' },
};
export const ORDERINGS = Object.keys(D.irf); // e.g. "infl,unemp,ffr"
export const BASE = 'infl,unemp,ffr';
export const orderLabel = (o: string) => o.split(',').map((k) => META[k as VarKey].short).join(' → ');
export const reduced = () => typeof window !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches;
export const sgn = (v: number, d = 2) => (v > 0 ? '+' : v < 0 ? '−' : '') + Math.abs(v).toFixed(d);

// ── custom chart types used by the labs ─────────────────────────
function head(el: HTMLElement, spec: any) {
  if (!spec.title && !spec.subtitle) return;
  const h = document.createElement('div'); h.className = 'viz-head';
  h.innerHTML = (spec.title ? `<div class="viz-title"></div>` : '') + (spec.subtitle ? `<div class="viz-sub"></div>` : '');
  if (spec.title) (h.querySelector('.viz-title') as HTMLElement).textContent = spec.title;
  if (spec.subtitle) (h.querySelector('.viz-sub') as HTMLElement).textContent = spec.subtitle;
  el.append(h);
}
function source(el: HTMLElement, spec: any) {
  if (!spec.source) return;
  const f = document.createElement('div'); f.className = 'viz-source';
  f.textContent = `Source: ${spec.source}`; el.append(f);
}
const nameColor = (n: string, i: number) => {
  const k = n.toLowerCase();
  if (k.startsWith('infl')) return col('infl');
  if (k.startsWith('unemp')) return col('unemp');
  if (k.startsWith('fed funds')) return col('ffr');
  return C.s[[0, 1, 2, 4][i % 4]];
};

// Small multiples of impulse responses: { h:[], unit, panels:[{name, series:[{name, pt, lo?, hi?}]}] }
registerViz('ch09-irf', (spec, el, ctx) => {
  head(el, spec);
  const wrap = document.createElement('div'); wrap.className = 'c9-grid'; wrap.style.cssText = 'display:grid;gap:16px;margin-top:.3rem';
  const n = spec.panels.length;
  const cols = ctx.width < 560 ? 1 : n;
  const w = Math.max(220, (ctx.width - 16 * (cols - 1)) / cols);
  const multi = spec.panels.some((p: any) => p.series.length > 1);
  const serNames: string[] = spec.panels[0].series.map((s: any) => s.name);
  const sc = (i: number) => (i === 0 ? C.forecast : C.s[5]);
  if (multi) {
    const lg = document.createElement('div'); lg.className = 'viz-legend';
    lg.innerHTML = serNames.map((s, i) => `<span><i style="border-top:2.5px ${i ? 'dashed' : 'solid'} ${sc(i)}"></i>${s}</span>`).join('') + `<span><i style="background:${sc(0)};opacity:.25;height:10px"></i>${Math.round(100 * (spec.ci ?? 0.9))}% band</span>`;
    el.append(lg);
  }
  for (const p of spec.panels) {
    const cell = document.createElement('div'); cell.className = 'c9-cell';
    const t = document.createElement('div'); t.className = 'c9-ptitle'; t.style.cssText = `color:${nameColor(p.name, 0)};font-weight:650;font-size:.86rem;margin:0 0 2px`; t.textContent = p.name; cell.append(t);
    const marks: any[] = [Plot.ruleY([0], { stroke: ctx.css('--border-strong'), strokeWidth: 1.5 })];
    p.series.forEach((s: any, i: number) => {
      const rows = spec.h.map((h: number, j: number) => ({ h, pt: s.pt[j], lo: s.lo?.[j], hi: s.hi?.[j], name: s.name }));
      const c = multi ? sc(i) : nameColor(p.name, 0);
      if (s.lo && s.hi) marks.push(Plot.areaY(rows, { x: 'h', y1: 'lo', y2: 'hi', fill: c, fillOpacity: 0.2, curve: 'monotone-x' }));
      marks.push(Plot.lineY(rows, { x: 'h', y: 'pt', stroke: c, strokeWidth: i ? 2.2 : 2.6, strokeDasharray: i ? '5,3' : undefined, curve: 'monotone-x' }));
      marks.push(Plot.tip(rows, Plot.pointerX({ x: 'h', y: 'pt', title: (r: any) => `${p.name}${multi ? ` (${r.name})` : ''}\n${r.h} quarter(s) after the shock: ${sgn(r.pt, 3)} ${spec.unit ?? ''}${r.lo != null ? `\nband ${sgn(r.lo, 2)} to ${sgn(r.hi, 2)}` : ''}` })));
    });
    cell.append(Plot.plot({
      width: w, height: 210, marginLeft: 44, marginRight: 10, marginTop: 10, marginBottom: 36,
      style: { background: 'transparent', color: ctx.css('--muted'), fontSize: '12px', overflow: 'visible' },
      x: { label: spec.xlab ?? 'quarters', labelAnchor: 'right', ticks: [0, 4, 8, 12, 16, 20] },
      y: { grid: true, label: spec.unit ?? null, nice: true, tickFormat: (d: number) => (d > 0 ? '+' : '') + d },
      marks, ariaLabel: `Impulse response of ${p.name}`,
    }));
    wrap.append(cell);
  }
  wrap.style.gridTemplateColumns = `repeat(${cols}, minmax(0, 1fr))`;
  el.append(wrap);
  source(el, spec);
});

// Stacked FEVD shares by horizon: { h:[], response, shares:{ name: [] } }
registerViz('ch09-fevd', (spec, el, ctx) => {
  head(el, spec);
  const names = Object.keys(spec.shares);
  const rows = names.flatMap((nm, i) => spec.h.map((h: number, j: number) => ({ h, share: 100 * spec.shares[nm][j], shock: nm, i })));
  const color = (nm: string) => nameColor(nm, names.indexOf(nm));
  const last = spec.h.length - 1;
  let cum = 0;
  const labels = names.map((nm) => { const v = spec.shares[nm][last]; const y = cum + v / 2; cum += v; return { h: spec.h[last], y, nm, v }; });
  const narrow = ctx.width < 560;
  el.append(Plot.plot({
    width: ctx.width, height: 300, marginLeft: 44, marginRight: narrow ? 12 : 150, marginBottom: 36,
    style: { background: 'transparent', color: ctx.css('--muted'), fontSize: '12px', overflow: 'visible' },
    x: { label: 'forecast horizon (quarters ahead)', labelAnchor: 'right' }, y: { label: 'share of forecast error variance (%)', domain: [0, 100], grid: true },
    marks: [
      Plot.areaY(rows, { x: 'h', y: 'share', fill: (d: any) => color(d.shock), fillOpacity: 0.78, order: names, z: 'shock', curve: 'monotone-x', stroke: ctx.css('--surface'), strokeWidth: 1 }),
      ...(narrow ? [] : [Plot.text(labels, { x: 'h', y: (d: any) => d.y * 100, text: (d: any) => `${d.nm} shock ${Math.round(100 * d.v)}%`, textAnchor: 'start', dx: 8, fill: (d: any) => color(d.nm), fontWeight: 650, fontSize: 12 })]),
      Plot.ruleX(spec.h, Plot.pointerX({ x: (d: number) => d, stroke: ctx.css('--text-2'), strokeDasharray: '3,3' })),
      Plot.tip(spec.h.map((h: number, j: number) => ({ h, y: 92, t: `${spec.response}, ${h} quarter(s) ahead\n` + names.map((nm) => `${nm} shock: ${(100 * spec.shares[nm][j]).toFixed(1)}%`).join('\n') })),
        Plot.pointerX({ x: 'h', y: 'y', title: 't' })),
    ],
  }));
  if (narrow) { const lg = document.createElement('div'); lg.className = 'viz-legend'; lg.innerHTML = names.map((n) => `<span><i style="background:${color(n)};height:10px"></i>${n} shock</span>`).join(''); el.append(lg); }
  source(el, spec);
});
