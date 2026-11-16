// Chapter 10 custom chart types for the code labs (emitted with viz_custom("ch10-…", …)).
// Registered on page load because the chapter's explorables import this file.
import * as Plot from '@observablehq/plot';
import { registerViz } from '../../lib/viz/render';
import { fmt } from '../../lib/viz/theme';

const D = (s: string) => new Date(s + (s.length === 10 ? 'T00:00:00' : ''));
const arr = (x: any) => (Array.isArray(x) ? x : x == null ? [] : [x]);

function head(el: HTMLElement, spec: any) {
  if (!spec.title && !spec.subtitle) return;
  const h = document.createElement('div'); h.className = 'viz-head';
  if (spec.title) { const t = document.createElement('div'); t.className = 'viz-title'; t.textContent = spec.title; h.append(t); }
  if (spec.subtitle) { const t = document.createElement('div'); t.className = 'viz-sub'; t.textContent = spec.subtitle; h.append(t); }
  el.append(h);
}
function foot(el: HTMLElement, spec: any) {
  if (!spec.source) return;
  const f = document.createElement('div'); f.className = 'viz-source'; f.innerHTML = `<span>Source: ${spec.source}</span>`; el.append(f);
}
function legend(el: HTMLElement, items: { label: string; css: string }[]) {
  const l = document.createElement('div'); l.className = 'viz-legend';
  l.innerHTML = items.map((i) => `<span><i style="${i.css}"></i>${i.label}</span>`).join('');
  el.append(l);
}

// ── spaghetti of simulated future paths ──────────────────────
registerViz('ch10-paths', (spec, el, ctx) => {
  head(el, spec);
  const hist = arr(spec.hist_date).map((d: string, i: number) => ({ date: D(d), value: arr(spec.hist)[i] }));
  const dates = arr(spec.dates).map(D);
  const P: number[][] = arr(spec.paths).map(arr);
  const last = hist[hist.length - 1];
  const paths = P.flatMap((p, k) => [{ date: last.date, value: last.value, k }, ...p.map((v, i) => ({ date: dates[i], value: v, k }))]);
  const act = arr(spec.actual_date).map((d: string, i: number) => ({ date: D(d), value: arr(spec.actual)[i] }));
  const fc = ctx.css('--c-forecast'), hc = ctx.css('--c-history'), ac = ctx.css('--c-actual');
  legend(el, [
    { label: 'History', css: `border-top:2.5px solid ${hc}` },
    { label: `${P.length} simulated futures`, css: `border-top:1.5px solid ${fc};opacity:.6` },
    ...(act.length ? [{ label: 'What actually happened', css: `border-top:2.5px dashed ${ac}` }] : []),
  ]);
  const marks: any[] = [
    Plot.ruleX([last.date], { stroke: ctx.css('--border-strong'), strokeDasharray: '3,4' }),
    Plot.text([last.date], { x: (d: any) => d, frameAnchor: 'top', dx: 6, dy: 4, textAnchor: 'start', text: () => 'Forecast starts', fill: ctx.css('--muted'), fontSize: 12 }),
    Plot.lineY(paths, { x: 'date', y: 'value', z: 'k', stroke: fc, strokeOpacity: 0.32, strokeWidth: 1.1 }),
    Plot.lineY(hist, { x: 'date', y: 'value', stroke: hc, strokeWidth: 2 }),
  ];
  if (act.length) marks.push(Plot.lineY([last, ...act], { x: 'date', y: 'value', stroke: ac, strokeWidth: 2.4, strokeDasharray: '5,3' }), Plot.dot(act, { x: 'date', y: 'value', fill: ac, r: 2.2 }));
  const tipRows = [...hist.map((r: any) => ({ ...r, k: 'History' })), ...act.map((r: any) => ({ ...r, k: 'Actual' }))];
  marks.push(Plot.tip(tipRows, Plot.pointerX({ x: 'date', y: 'value', title: (r: any) => `${r.k} · ${r.date.toISOString().slice(0, 7)}\n${fmt(r.value)}${spec.ylab ? ' ' + spec.ylab : ''}` })));
  el.append(Plot.plot({
    width: ctx.width, height: Math.max(260, Math.min(420, ctx.width * 0.5)), marginLeft: 60, marginRight: 20, marginTop: 18,
    style: { background: 'transparent', color: ctx.css('--muted'), fontSize: '12px', overflow: 'visible' },
    x: { label: null }, y: { grid: true, nice: true, label: spec.ylab ?? null, tickFormat: fmt }, marks,
  }));
  foot(el, spec);
});

// ── coverage audit strip: one row per method/horizon ─────────
registerViz('ch10-strip', (spec, el, ctx) => {
  head(el, spec);
  const rows = arr(spec.rows);
  const good = ctx.css('--good'), bad = ctx.css('--danger');
  const data = rows.flatMap((r: any) => arr(r.date).map((d: string, i: number) => ({ row: r.name, date: D(d), inside: !!arr(r.inside)[i] })));
  const sum = document.createElement('div'); sum.className = 'viz-legend';
  sum.innerHTML = rows.map((r: any) => { const v = arr(r.inside); const p = (100 * v.filter(Boolean).length) / v.length;
    return `<span><b style="color:var(--text)">${r.name}:</b>&nbsp;${p.toFixed(1)}% inside (promised ${spec.nominal ?? 80}%)</span>`; }).join('') +
    `<span><i style="background:${good};height:8px;width:8px;border-radius:2px"></i>inside (short bar)</span><span><i style="background:${bad};height:14px;width:8px;border-radius:2px"></i>miss (tall bar)</span>`;
  el.append(sum);
  const month = 30.4 * 864e5;
  el.append(Plot.plot({
    width: ctx.width, height: 46 + rows.length * 46, marginLeft: Math.min(150, 14 + 7.2 * Math.max(...rows.map((r: any) => r.name.length))), marginRight: 16, marginTop: 6,
    style: { background: 'transparent', color: ctx.css('--muted'), fontSize: '12px', overflow: 'visible' },
    x: { label: null }, y: { label: null, padding: 0.18, domain: rows.map((r: any) => r.name) },
    marks: [
      Plot.rect(data.filter((d: any) => d.inside), { x1: 'date', x2: (d: any) => new Date(+d.date + month * 0.82), y: 'row', fill: good, fillOpacity: 0.6, insetTop: 9, insetBottom: 9 }),
      Plot.rect(data.filter((d: any) => !d.inside), { x1: 'date', x2: (d: any) => new Date(+d.date + month * 0.82), y: 'row', fill: bad }),
      Plot.tip(data, Plot.pointerX({ x: 'date', y: 'row', title: (d: any) => `${d.row} · ${d.date.toISOString().slice(0, 7)}\n${d.inside ? 'Inside the interval' : 'Outside: a miss'}` })),
    ],
  }));
  foot(el, spec);
});

// ── histogram with labeled vertical markers ──────────────────
registerViz('ch10-hist', (spec, el, ctx) => {
  head(el, spec);
  const v = arr(spec.values).filter((x: any) => Number.isFinite(x)).map((x: number) => ({ x }));
  const mk = arr(spec.markers);
  const cols = [ctx.css('--muted'), ctx.css('--c-forecast'), ctx.css('--c-actual')];
  const colOf = (i: number) => (mk.length === 1 ? ctx.css('--c-forecast') : cols[i % cols.length]);
  el.append(Plot.plot({
    width: ctx.width, height: Math.max(220, Math.min(340, ctx.width * 0.4)), marginLeft: 50, marginRight: 20, marginTop: 30,
    style: { background: 'transparent', color: ctx.css('--muted'), fontSize: '12px', overflow: 'visible' },
    x: { label: spec.xlab ?? null, tickFormat: fmt }, y: { grid: true, label: 'count' },
    marks: [
      Plot.rectY(v, Plot.binX({ y: 'count' }, { x: 'x', thresholds: spec.bins ?? 30, fill: ctx.css('--c-s1'), fillOpacity: 0.75, insetLeft: 1, insetRight: 1, tip: true } as any)),
      Plot.ruleY([0], { stroke: ctx.css('--border-strong') }),
      ...mk.map((m: any, i: number) => Plot.ruleX([m.x], { stroke: colOf(i), strokeWidth: 2.4, strokeDasharray: i === 0 && mk.length > 1 ? '4,4' : undefined })),
      ...mk.map((m: any, i: number) => Plot.text([m], { x: 'x', frameAnchor: 'top', dy: -18 + (i % 2) * 14, text: (d: any) => `${d.label}: ${fmt(d.x)}`, fill: ctx.css('--text'), fontSize: 12, fontWeight: 600, textAnchor: i % 2 ? 'start' : 'end', dx: i % 2 ? 6 : -6, stroke: ctx.css('--surface'), strokeWidth: 3, paintOrder: 'stroke' } as any)),
    ],
  }));
  foot(el, spec);
});
