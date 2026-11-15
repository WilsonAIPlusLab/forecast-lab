// Renders chart specs emitted by R/Python viz_*() helpers (or built in JS) with Observable Plot.
import * as Plot from '@observablehq/plot';

export type Spec = { type: string; title?: string; subtitle?: string; [k: string]: any };
type Renderer = (spec: Spec, el: HTMLElement, ctx: Ctx) => void;
interface Ctx { width: number; css: (v: string) => string; animate: boolean }

const registry: Record<string, Renderer> = {};
export function registerViz(type: string, fn: Renderer) { registry[type] = fn; }

const css = (v: string) => getComputedStyle(document.documentElement).getPropertyValue(v).trim() || '#888';
const palette = () => ['--c-s1', '--c-s2', '--c-s3', '--c-s4', '--c-s5', '--c-s6'].map(css);
const D = (s: string) => new Date(s + (s.length === 10 ? 'T00:00:00' : ''));
const fmt = (v: any) => (typeof v === 'number' ? (Math.abs(v) >= 1e4 ? v.toLocaleString(undefined, { maximumFractionDigits: 0 }) : +v.toPrecision(5) + '') : v ?? '—');

function rows(ser: any) {
  if (!ser) return [];
  return ser.date.map((d: string, i: number) => ({ date: D(d), value: ser.value[i], name: ser.name })).filter((r: any) => r.value !== null && Number.isFinite(r.value));
}

function header(el: HTMLElement, spec: Spec) {
  if (!spec.title && !spec.subtitle) return;
  const h = document.createElement('div');
  h.className = 'viz-head';
  if (spec.title) { const t = document.createElement('div'); t.className = 'viz-title'; t.textContent = spec.title; h.append(t); }
  if (spec.subtitle) { const t = document.createElement('div'); t.className = 'viz-sub'; t.textContent = spec.subtitle; h.append(t); }
  el.append(h);
}

function legend(el: HTMLElement, items: { label: string; color: string; dash?: boolean; band?: boolean }[]) {
  const l = document.createElement('div'); l.className = 'viz-legend';
  for (const it of items) {
    const s = document.createElement('span');
    s.innerHTML = `<i style="${it.band ? `background:${it.color};opacity:.35;height:10px` : `border-top:2.5px ${it.dash ? 'dashed' : 'solid'} ${it.color}`}"></i>${it.label}`;
    l.append(s);
  }
  el.append(l);
}

/** End-of-line labels (direct labeling) with a halo; falls back to a legend on narrow screens. */
function endLabels(data: any[], z: string, color: (d: any) => string, ctx: Ctx, x = 'date', y = 'value') {
  return Plot.text(data, Plot.selectLast({ x, y, z, text: z, fill: color, textAnchor: 'start', dx: 7, fontWeight: 650, fontSize: 12, stroke: ctx.css('--surface'), strokeWidth: 3, paintOrder: 'stroke' } as any));
}
const narrow = (ctx: Ctx) => ctx.width < 560;

function finish(el: HTMLElement, chart: Element, ctx: Ctx, spec?: Spec) {
  el.append(chart);
  if (spec?.source) {
    const f = document.createElement('div'); f.className = 'viz-source';
    f.innerHTML = `<span>Source: ${spec.source}</span>`;
    el.append(f);
  }
  if (!ctx.animate) return;
  requestAnimationFrame(() => {
    chart.querySelectorAll('g.line-anim path').forEach((p: any) => {
      const len = p.getTotalLength?.() || 3000; p.style.setProperty('--len', String(Math.ceil(len)));
    });
    (chart as HTMLElement).classList?.add('anim-draw');
    if (chart.tagName === 'FIGURE') chart.querySelector('svg')?.classList.add('anim-draw');
  });
}

const base = (ctx: Ctx, extra: any = {}) => ({
  width: ctx.width, height: Math.max(260, Math.min(440, ctx.width * 0.52)),
  marginLeft: 56, marginRight: 24, marginTop: 16, marginBottom: 34,
  style: { background: 'transparent', color: ctx.css('--muted'), fontSize: '12px', overflow: 'visible' },
  y: { grid: true, nice: true, tickFormat: (d: number) => fmt(d), ...(extra.y || {}) },
  x: { ...(extra.x || {}) },
  ...extra.root,
});

// ── time series ─────────────────────────────────────────────
registry.ts = (spec, el, ctx) => {
  header(el, spec);
  const pal = palette();
  const data = spec.series.flatMap((s: any) => rows(s));
  const names = spec.series.map((s: any) => s.name);
  const color = (n: string) => pal[names.indexOf(n) % pal.length];
  const marks: any[] = [];
  if (spec.recessions?.length) {
    const r = spec.recessions.map((d: string) => D(d));
    const [lo, hi] = [Math.min(...data.map((d: any) => +d.date)), Math.max(...data.map((d: any) => +d.date))];
    marks.push(Plot.rectX(r.filter((d: Date) => +d >= lo && +d <= hi), { x1: (d: Date) => d, x2: (d: Date) => new Date(+d + 31 * 864e5), fill: ctx.css('--muted'), fillOpacity: 0.16 }));
  }
  if (spec.facet && names.length > 1) {
    const wrap = document.createElement('div'); wrap.className = 'viz-facets';
    for (const n of names) {
      const d = data.filter((r: any) => r.name === n);
      const c = document.createElement('div'); c.className = 'viz-facet';
      c.innerHTML = `<div class="viz-facet-t" style="color:${color(n)}">${n}</div>`;
      const w = names.length > 2 ? Math.max(240, (ctx.width - 24) / 2) : ctx.width;
      c.append(Plot.plot({ ...base({ ...ctx, width: w }), height: 170, marginLeft: 50, marks: [...marks, Plot.lineY(d, { x: 'date', y: 'value', stroke: color(n), strokeWidth: 1.6, className: 'line-anim' }), Plot.tip(d, Plot.pointerX({ x: 'date', y: 'value', title: (r: any) => `${r.date.toISOString().slice(0, 10)}\n${fmt(r.value)}` }))] }));
      wrap.append(c);
    }
    finish(el, wrap, ctx); return;
  }
  marks.push(Plot.lineY(data, { x: 'date', y: 'value', z: 'name', stroke: (d: any) => color(d.name), strokeWidth: 1.8, className: 'line-anim' }));
  marks.push(Plot.ruleX(data, Plot.pointerX({ x: 'date', stroke: ctx.css('--border-strong') })));
  marks.push(Plot.dot(data, Plot.pointerX({ x: 'date', y: 'value', fill: (d: any) => color(d.name), r: 3.5 })));
  marks.push(Plot.tip(data, Plot.pointerX({ x: 'date', y: 'value', title: (r: any) => `${r.name}\n${r.date.toISOString().slice(0, 7)}: ${fmt(r.value)}` })));
  const direct = names.length > 1 && !narrow(ctx);
  if (direct) marks.push(endLabels(data, 'name', (d: any) => color(d.name), ctx));
  else if (names.length > 1) legend(el, names.map((n: string) => ({ label: n, color: color(n) })));
  finish(el, Plot.plot({ ...base(ctx, { y: { type: spec.log ? 'log' : 'linear', label: spec.ylab ?? null } }), marginRight: direct ? 16 + 7.5 * Math.max(...names.map((n: string) => n.length)) : 24, x: { label: null }, marks }), ctx, spec);
};

// ── forecast fan chart ──────────────────────────────────────
registry.forecast = (spec, el, ctx) => {
  header(el, spec);
  const H = rows(spec.history), M = rows(spec.mean), A = rows(spec.actual), F = rows(spec.fitted);
  const fc = css('--c-forecast'), band = css('--c-band');
  const marks: any[] = [];
  const bands = (spec.bands || []).slice().sort((a: any, b: any) => parseFloat(b.level) - parseFloat(a.level));
  bands.forEach((b: any, i: number) => {
    const d = M.map((m: any, j: number) => ({ date: m.date, lo: b.lo[j], hi: b.hi[j] }));
    // connect band to last history point for a seamless fan
    const last = H[H.length - 1]; if (last) d.unshift({ date: last.date, lo: last.value, hi: last.value });
    marks.push(Plot.areaY(d, { x: 'date', y1: 'lo', y2: 'hi', fill: band, fillOpacity: bands.length > 1 ? (i === 0 ? 0.16 : 0.3) : 0.22, curve: 'monotone-x', className: 'anim-band' }));
  });
  const origin = H[H.length - 1]?.date;
  if (origin) marks.push(Plot.ruleX([origin], { stroke: ctx.css('--border-strong'), strokeDasharray: '3,4' }), Plot.text([origin], { x: (d: any) => d, frameAnchor: 'top', dx: 6, dy: 4, textAnchor: 'start', text: () => 'Forecast starts', fill: ctx.css('--muted'), fontSize: 12 }));
  marks.push(Plot.lineY(H, { x: 'date', y: 'value', stroke: css('--c-history'), strokeWidth: 1.6, className: 'line-anim' }));
  if (F.length) marks.push(Plot.lineY(F, { x: 'date', y: 'value', stroke: css('--c-fitted'), strokeWidth: 1.2, strokeOpacity: 0.85 }));
  if (A.length) marks.push(Plot.lineY(A, { x: 'date', y: 'value', stroke: css('--c-actual'), strokeWidth: 2, strokeDasharray: '5,3' }), Plot.dot(A, { x: 'date', y: 'value', fill: css('--c-actual'), r: 2.2 }));
  const Mj = H.length ? [{ ...H[H.length - 1] }, ...M] : M;
  marks.push(Plot.lineY(Mj, { x: 'date', y: 'value', stroke: fc, strokeWidth: 2.6 }), Plot.dot(M, { x: 'date', y: 'value', fill: fc, r: 2.4 }));
  const all = [...H.map((r: any) => ({ ...r, k: 'Actual' })), ...M.map((r: any, j: number) => ({ ...r, k: 'Forecast', lo: bands[bands.length - 1]?.lo[j], hi: bands[bands.length - 1]?.hi[j], lv: bands[bands.length - 1]?.level })), ...A.map((r: any) => ({ ...r, k: 'Held-out actual' }))];
  marks.push(Plot.tip(all, Plot.pointerX({ x: 'date', y: 'value', title: (r: any) => `${r.k} · ${r.date.toISOString().slice(0, 7)}\n${fmt(r.value)}${r.lo != null ? `\n${r.lv} interval: ${fmt(r.lo)} – ${fmt(r.hi)}` : ''}` })));
  const lg: any[] = [{ label: 'History', color: css('--c-history') }];
  if (F.length) lg.push({ label: 'Fitted', color: css('--c-fitted') });
  lg.push({ label: spec.method ? `Forecast (${spec.method})` : 'Forecast', color: fc });
  bands.slice().reverse().forEach((b: any) => lg.push({ label: `${b.level} interval`, color: band, band: true }));
  if (A.length) lg.push({ label: 'What actually happened', color: css('--c-actual'), dash: true });
  if (!narrow(ctx) && bands.length && M.length) {
    // label each band at its right edge
    const lastIdx = M.length - 1;
    bands.forEach((b: any) => marks.push(Plot.text([{ date: M[lastIdx].date, v: b.hi[lastIdx] }], { x: 'date', y: 'v', text: () => b.level, dx: 6, dy: 2, textAnchor: 'start', fill: ctx.css('--muted'), fontSize: 12 })));
  }
  legend(el, lg);
  finish(el, Plot.plot({ ...base(ctx, { y: { label: spec.ylab ?? null } }), marginRight: bands.length ? 44 : 24, x: { label: null }, marks }), ctx, spec);
};

// ── several model forecasts vs actual ───────────────────────
registry.compare = (spec, el, ctx) => {
  header(el, spec);
  const pal = palette();
  const H = rows(spec.history), A = rows(spec.actual);
  const models = spec.models.map((m: any) => rows(m));
  const marks: any[] = [];
  if (H.length) marks.push(Plot.lineY(H, { x: 'date', y: 'value', stroke: css('--c-history'), strokeWidth: 1.5, className: 'line-anim' }));
  if (A.length) marks.push(Plot.lineY(A, { x: 'date', y: 'value', stroke: css('--c-actual'), strokeWidth: 2.4, strokeDasharray: '5,3' }));
  models.forEach((m: any[], i: number) => marks.push(Plot.lineY(m, { x: 'date', y: 'value', stroke: pal[i % pal.length], strokeWidth: 2, className: 'line-anim' })));
  const all = models.flat().concat(A.map((r: any) => ({ ...r, name: 'Actual' })));
  marks.push(Plot.tip(all, Plot.pointer({ x: 'date', y: 'value', title: (r: any) => `${r.name} · ${r.date.toISOString().slice(0, 7)}\n${fmt(r.value)}` })));
  const direct = !narrow(ctx);
  const named = models.map((m: any[], i: number) => m.map((r: any) => ({ ...r, k: i })));
  if (direct) {
    marks.push(endLabels(named.flat(), 'name', (d: any) => pal[d.k % pal.length], ctx));
    if (A.length) marks.push(endLabels(A.map((r: any) => ({ ...r, name: 'Actual' })), 'name', () => css('--c-actual'), ctx));
  } else {
    const lg: any[] = [];
    if (H.length) lg.push({ label: 'History', color: css('--c-history') });
    if (A.length) lg.push({ label: 'Actual', color: css('--c-actual'), dash: true });
    spec.models.forEach((m: any, i: number) => lg.push({ label: m.name, color: pal[i % pal.length] }));
    legend(el, lg);
  }
  const longest = Math.max(6, ...spec.models.map((m: any) => m.name.length));
  finish(el, Plot.plot({ ...base(ctx), marginRight: direct ? 18 + 7.5 * longest : 24, x: { label: null }, marks }), ctx, spec);
};

// ── bars (horizontal, sorted) ───────────────────────────────
registry.bars = (spec, el, ctx) => {
  header(el, spec);
  let d = spec.labels.map((l: string, i: number) => ({ label: l, value: spec.values[i] }));
  if (spec.sort !== false) d = d.sort((a: any, b: any) => b.value - a.value);
  const hl = [].concat(spec.highlight ?? []);
  const chart = Plot.plot({
    width: ctx.width, height: Math.max(140, d.length * 30 + 40), marginLeft: Math.min(200, 12 + 7.2 * Math.max(...d.map((r: any) => r.label.length))), marginRight: 60,
    style: { background: 'transparent', color: ctx.css('--muted'), fontSize: '12px' },
    x: { grid: true, label: spec.xlab ?? null, tickFormat: fmt }, y: { label: null, domain: d.map((r: any) => r.label) },
    marks: [
      Plot.barX(d, { y: 'label', x: 'value', fill: (r: any) => (hl.length && !hl.includes(r.label) ? css('--surface-3') : css('--c-s1')), rx: 4, className: 'bar-anim' }),
      Plot.text(d, { y: 'label', x: 'value', text: (r: any) => fmt(r.value), dx: 6, textAnchor: 'start', fill: css('--text-2') }),
      Plot.ruleX([0], { stroke: css('--border-strong') }),
    ],
  });
  finish(el, chart, ctx, spec);
};

// ── scatter with OLS line ───────────────────────────────────
registry.scatter = (spec, el, ctx) => {
  header(el, spec);
  const d = spec.x.map((x: number, i: number) => ({ x, y: spec.y[i], label: spec.labels?.[i] })).filter((r: any) => r.x != null && r.y != null);
  const marks: any[] = [Plot.dot(d, { x: 'x', y: 'y', fill: css('--c-s2'), fillOpacity: 0.55, r: 3.2 })];
  if (spec.fit !== false) marks.push(Plot.linearRegressionY(d, { x: 'x', y: 'y', stroke: css('--c-s1'), fill: css('--c-s1'), fillOpacity: 0.15, strokeWidth: 2.4 }));
  marks.push(Plot.tip(d, Plot.pointer({ x: 'x', y: 'y', title: (r: any) => `${r.label ? r.label + '\n' : ''}${spec.xlab}: ${fmt(r.x)}\n${spec.ylab}: ${fmt(r.y)}` })));
  finish(el, Plot.plot({ ...base(ctx), x: { label: spec.xlab, grid: true, tickFormat: fmt }, y: { label: spec.ylab, grid: true, tickFormat: fmt }, marks }), ctx, spec);
};

// ── lines vs numeric x ──────────────────────────────────────
registry.lines = (spec, el, ctx) => {
  header(el, spec);
  const pal = palette();
  const d = spec.series.flatMap((s: any, k: number) => spec.x.map((x: number, i: number) => ({ x, y: s.value[i], name: s.name, k })).filter((r: any) => r.y != null));
  const marks: any[] = [
    Plot.lineY(d, { x: 'x', y: 'y', z: 'name', stroke: (r: any) => pal[r.k % pal.length], strokeWidth: 2.2, className: 'line-anim' }),
    Plot.dot(d, { x: 'x', y: 'y', fill: (r: any) => pal[r.k % pal.length], r: 2.6 }),
    Plot.tip(d, Plot.pointer({ x: 'x', y: 'y', title: (r: any) => `${r.name}
${spec.xlab ?? 'x'} = ${fmt(r.x)}: ${fmt(r.y)}` })),
  ];
  const direct = spec.series.length > 1 && !narrow(ctx);
  if (direct) marks.push(endLabels(d, 'name', (r: any) => pal[r.k % pal.length], ctx, 'x', 'y'));
  else if (spec.series.length > 1) legend(el, spec.series.map((s: any, k: number) => ({ label: s.name, color: pal[k % pal.length] })));
  const longest = Math.max(...spec.series.map((s: any) => s.name.length));
  finish(el, Plot.plot({ ...base(ctx, { y: { label: spec.ylab ?? null, zero: !!spec.zero } }), marginRight: direct ? 18 + 7.5 * longest : 24, height: Math.max(240, Math.min(360, ctx.width * 0.42)), x: { label: spec.xlab ?? null, tickFormat: fmt }, marks }), ctx, spec);
};

// ── ACF / PACF lollipop ─────────────────────────────────────
registry.acf = (spec, el, ctx) => {
  header(el, { ...spec, title: spec.title ?? `${spec.kind}` });
  const d = spec.lag.map((l: number, i: number) => ({ lag: l, v: spec.value[i], sig: Math.abs(spec.value[i]) > spec.ci }));
  const chart = Plot.plot({
    ...base(ctx), height: 240, y: { grid: true, label: spec.kind, domain: [-1, 1] }, x: { label: 'lag', ticks: 12 },
    marks: [
      Plot.areaY([{ l: 0 }, { l: d[d.length - 1].lag }], { x: 'l', y1: -spec.ci, y2: spec.ci, fill: css('--c-s2'), fillOpacity: 0.12 }),
      Plot.ruleY([0], { stroke: css('--border-strong') }),
      Plot.ruleX(d, { x: 'lag', y1: 0, y2: 'v', stroke: (r: any) => (r.sig ? css('--c-s1') : css('--muted')), strokeWidth: 2 }),
      Plot.dot(d, { x: 'lag', y: 'v', fill: (r: any) => (r.sig ? css('--c-s1') : css('--muted')), r: 3.5 }),
      Plot.tip(d, Plot.pointerX({ x: 'lag', y: 'v', title: (r: any) => `lag ${r.lag}: ${r.v.toFixed(3)}${r.sig ? '  (significant)' : ''}` })),
    ],
  });
  finish(el, chart, ctx);
};

// ── decomposition: 4 stacked panels ─────────────────────────
registry.decomp = (spec, el, ctx) => {
  header(el, spec);
  const cols = [css('--c-history'), css('--c-s1'), css('--c-s3'), css('--c-s4')];
  const wrap = document.createElement('div'); wrap.className = 'viz-stack';
  spec.parts.forEach((p: any, i: number) => {
    const d = rows(p);
    const row = document.createElement('div'); row.className = 'viz-stack-row';
    row.innerHTML = `<div class="viz-stack-label" style="color:${cols[i]}">${p.name}</div>`;
    row.append(Plot.plot({
      width: ctx.width, height: i === 0 ? 150 : 110, marginLeft: 56, marginRight: 20, marginTop: 8, marginBottom: i === spec.parts.length - 1 ? 28 : 8,
      style: { background: 'transparent', color: ctx.css('--muted'), fontSize: '11px' },
      x: { axis: i === spec.parts.length - 1 ? 'bottom' : null, label: null }, y: { grid: true, ticks: 3, tickFormat: fmt, label: null },
      marks: [p.name === 'remainder' ? Plot.ruleY([0], { stroke: css('--border-strong') }) : null,
        p.name === 'remainder' ? Plot.ruleX(d, { x: 'date', y1: 0, y2: 'value', stroke: cols[i], strokeOpacity: 0.7 }) : Plot.lineY(d, { x: 'date', y: 'value', stroke: cols[i], strokeWidth: 1.5, className: 'line-anim' }),
        Plot.tip(d, Plot.pointerX({ x: 'date', y: 'value', title: (r: any) => `${p.name} ${r.date.toISOString().slice(0, 7)}: ${fmt(r.value)}` }))].filter(Boolean) as any,
    }));
    wrap.append(row);
  });
  finish(el, wrap, ctx, spec);
};

// ── table with best-cell highlight ──────────────────────────
registry.table = (spec, el) => {
  header(el, spec);
  const t = document.createElement('table'); t.className = 'viz-table';
  const hl = [].concat(spec.highlight ?? []) as string[];
  const best: Record<number, number> = {};
  spec.columns.forEach((c: string, j: number) => {
    if (!hl.includes(c)) return;
    const vals = spec.rows.map((r: any[]) => r[j]).filter((v: any) => typeof v === 'number');
    best[j] = spec.lower_is_better === false ? Math.max(...vals) : Math.min(...vals.map(Math.abs));
  });
  t.innerHTML = `<thead><tr>${spec.columns.map((c: string) => `<th>${c}</th>`).join('')}</tr></thead><tbody>${spec.rows
    .map((r: any[]) => `<tr>${r.map((v: any, j: number) => `<td class="${typeof v === 'number' ? 'num' : ''} ${best[j] !== undefined && typeof v === 'number' && (spec.lower_is_better === false ? v === best[j] : Math.abs(v) === best[j]) ? 'best' : ''}">${fmt(v)}</td>`).join('')}</tr>`)
    .join('')}</tbody>`;
  const w = document.createElement('div'); w.className = 'viz-table-wrap'; w.append(t);
  el.append(w);
};

// ── exercise check result ───────────────────────────────────
registry.check = (spec, el) => {
  const d = document.createElement('div'); d.className = `viz-check ${spec.pass ? 'pass' : 'fail'}`; d.setAttribute('role', 'status');
  d.innerHTML = `<b>${spec.pass ? '✓' : '…'}</b><div>${spec.pass ? '<strong>Correct.</strong> ' : '<strong>Not yet.</strong> '}${spec.message ?? ''}</div>`;
  el.append(d);
};

// ── KPI cards ───────────────────────────────────────────────
registry.kpi = (spec, el) => {
  header(el, spec);
  const w = document.createElement('div'); w.className = 'viz-kpis';
  w.innerHTML = spec.items.map((it: any) => `<div class="viz-kpi"><div class="viz-kpi-v">${fmt(it.value)}</div><div class="viz-kpi-l">${it.label}</div></div>`).join('');
  el.append(w);
};

/** Download the first SVG chart inside el as PNG (2x, themed background) or SVG — for instructors' slides. */
export async function exportChart(el: HTMLElement, kind: 'png' | 'svg', name = 'chart') {
  const svg = el.querySelector('svg') as SVGSVGElement | null; if (!svg) return;
  const clone = svg.cloneNode(true) as SVGSVGElement;
  const W = svg.clientWidth || +svg.getAttribute('width')!, H = svg.clientHeight || +svg.getAttribute('height')!;
  clone.setAttribute('xmlns', 'http://www.w3.org/2000/svg'); clone.setAttribute('width', String(W)); clone.setAttribute('height', String(H));
  // inline computed text colours/fonts so the file looks right outside the page
  const src = svg.querySelectorAll('text'), dst = clone.querySelectorAll('text');
  src.forEach((t, i) => { const cs = getComputedStyle(t); dst[i].setAttribute('fill', cs.fill); dst[i].setAttribute('font-family', 'Inter, Arial, sans-serif'); dst[i].setAttribute('font-size', cs.fontSize); });
  clone.insertAdjacentHTML('afterbegin', `<rect width="100%" height="100%" fill="${css('--surface')}"/>`);
  const xml = new XMLSerializer().serializeToString(clone);
  const blob = new Blob([xml], { type: 'image/svg+xml' });
  const a = document.createElement('a'); a.download = `${name}.${kind}`;
  if (kind === 'svg') { a.href = URL.createObjectURL(blob); a.click(); return; }
  const img = new Image(); img.src = URL.createObjectURL(blob); await img.decode();
  const c = document.createElement('canvas'); c.width = W * 2; c.height = H * 2;
  const g = c.getContext('2d')!; g.scale(2, 2); g.drawImage(img, 0, 0);
  a.href = c.toDataURL('image/png'); a.click();
}

function addTools(el: HTMLElement, spec: Spec) {
  if (!el.querySelector('svg') || spec.type === 'check') return;
  const t = document.createElement('div'); t.className = 'viz-tools';
  const name = (spec.title || spec.type).toLowerCase().replace(/[^a-z0-9]+/g, '-').slice(0, 50);
  t.innerHTML = '<button data-k="png" title="Download PNG for slides">PNG</button><button data-k="svg" title="Download SVG">SVG</button>';
  t.addEventListener('click', (e) => { const k = (e.target as HTMLElement).dataset.k as any; if (k) exportChart(el, k, name); });
  el.append(t);
}

export function renderSpec(spec: Spec, el: HTMLElement, opts: { animate?: boolean } = {}) {
  el.innerHTML = '';
  el.classList.add('viz');
  const width = Math.max(280, el.clientWidth || el.parentElement?.clientWidth || 720);
  const fn = registry[spec.type];
  if (!fn) { el.innerHTML = `<pre class="viz-unknown">Unknown chart type "${spec.type}"</pre>`; return; }
  try { fn(spec, el, { width, css, animate: opts.animate !== false }); addTools(el, spec); }
  catch (e: any) { el.innerHTML = `<pre class="viz-unknown">Chart error: ${e?.message}</pre>`; console.error(e); }
}
