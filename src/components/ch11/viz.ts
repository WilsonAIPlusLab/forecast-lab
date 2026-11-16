// Chapter 11 custom chart: a regression-tree diagram, emitted from R (rpart frame) or Python (sklearn tree_).
// R/Python: viz_custom("ch11-tree", title=, subtitle=, nodes = [{id, var, n, yval, label}])
// Node ids are heap-indexed (root 1, children 2k and 2k+1), as in rpart's frame row names.
import { registerViz } from '../../lib/viz/render';

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]!);

/** Make split labels readable: "month=3,5,12" -> "month: Mar, May, Dec"; "g12< -15.3" -> "g12 < −15.3". */
function pretty(label: string) {
  const m = label.match(/^month\s*=\s*(.+)$/);
  if (m) {
    const ms = m[1].split(',').map((s) => MONTHS[+s.trim() - 1] ?? s.trim());
    return 'month: ' + (ms.length > 5 ? ms.slice(0, 4).join(', ') + ` +${ms.length - 4} more` : ms.join(', '));
  }
  return label.replace(/\s*(<=|>=|<|>)\s*/, ' $1 ').replace(/-(?=\d)/g, '−');
}

registerViz('ch11-tree', (spec, el, ctx) => {
  if (spec.title || spec.subtitle) {
    const h = document.createElement('div'); h.className = 'viz-head';
    h.innerHTML = (spec.title ? `<div class="viz-title">${esc(spec.title)}</div>` : '') + (spec.subtitle ? `<div class="viz-sub">${esc(spec.subtitle)}</div>` : '');
    el.append(h);
  }
  // R sends a data.frame as an array of row objects; accept column-wise too.
  let nodes: any = spec.nodes;
  if (!Array.isArray(nodes)) { const k = Object.keys(nodes); nodes = nodes[k[0]].map((_: any, i: number) => Object.fromEntries(k.map((c) => [c, (spec.nodes as any)[c][i]]))); }
  const byId = new Map<number, any>(nodes.map((n: any) => [+n.id, { ...n, id: +n.id }]));
  const isLeaf = (n: any) => n.var === '<leaf>' || !byId.has(2 * n.id);
  // layout: leaves get consecutive slots (in-order), parents sit above the middle of their children
  let slot = 0; let maxDepth = 0;
  const place = (id: number, depth: number): number => {
    const n = byId.get(id)!; n.depth = depth; maxDepth = Math.max(maxDepth, depth);
    if (isLeaf(n)) { n.slot = slot++; return n.slot; }
    const a = place(2 * id, depth + 1), b = place(2 * id + 1, depth + 1);
    n.slot = (a + b) / 2; return n.slot;
  };
  place(1, 0);
  const leaves = slot;
  const W = Math.max(ctx.width, 300), padX = 16;
  const colW = (W - 2 * padX) / Math.max(leaves, 1);
  const boxW = Math.min(118, colW - 8), boxH = 46, rowH = 96, top = 8;
  const H = top + maxDepth * rowH + boxH + 10;
  const X = (n: any) => padX + (n.slot + 0.5) * colW, Y = (n: any) => top + n.depth * rowH;
  const vals = nodes.filter(isLeaf).map((n: any) => +n.yval);
  const vmax = Math.max(...vals.map(Math.abs), 1e-9);
  const small = colW < 92;
  let edges = '', boxes = '';
  for (const n of byId.values()) {
    if (n.id > 1) {
      const p = byId.get(Math.floor(n.id / 2)); if (!p) continue;
      const x1 = X(p), y1 = Y(p) + boxH, x2 = X(n), y2 = Y(n), ym = (y1 + y2) / 2;
      edges += `<path d="M${x1},${y1} V${ym} H${x2} V${y2}" class="t-edge"/>`;
      if (!small || n.depth <= 1) edges += `<text x="${x2 + (n.id % 2 ? 5 : -5)}" y="${ym - 6}" text-anchor="${n.id % 2 ? 'start' : 'end'}" class="t-lab">${esc(pretty(String(n.label)))}</text>`;
    }
    const leaf = isLeaf(n), v = +n.yval;
    const fill = leaf ? (v >= 0 ? 'var(--c-s3)' : 'var(--c-s2)') : 'var(--surface-2)';
    const op = leaf ? 0.18 + 0.5 * Math.abs(v) / vmax : 1;
    const sign = v > 0 ? '+' : v < 0 ? '−' : '';
    boxes += `<g transform="translate(${X(n) - boxW / 2},${Y(n)})"><title>${leaf ? 'Leaf' : 'Split on ' + esc(String(n.var))}: ${n.n} months, average ${v.toFixed(2)}</title>`
      + `<rect width="${boxW}" height="${boxH}" rx="8" fill="${fill}" fill-opacity="${op.toFixed(2)}" class="${leaf ? 't-leaf' : 't-node'}"/>`
      + `<text x="${boxW / 2}" y="20" text-anchor="middle" class="t-v">${sign}${Math.abs(v).toFixed(1)}${spec.unit ?? '%'}</text>`
      + `<text x="${boxW / 2}" y="36" text-anchor="middle" class="t-n">${n.n} months</text></g>`;
  }
  const wrap = document.createElement('div'); wrap.className = 'ch11-tree';
  wrap.innerHTML = `<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" role="img" aria-label="Regression tree diagram with ${leaves} leaves"><style>
    .t-edge{fill:none;stroke:var(--border-strong);stroke-width:1.5}
    .t-lab{font:600 12px var(--font-ui);fill:var(--text-2);paint-order:stroke;stroke:var(--surface);stroke-width:3px}
    .t-node{stroke:var(--border-strong)} .t-leaf{stroke:var(--border-strong)}
    .t-v{font:650 14px var(--font-ui);fill:var(--text);font-variant-numeric:tabular-nums}
    .t-n{font:500 12px var(--font-ui);fill:var(--muted)}
  </style>${edges}${boxes}</svg>`;
  el.append(wrap);
  const note = document.createElement('div'); note.className = 'viz-sub'; note.style.marginTop = '.3rem';
  note.textContent = 'Each box shows the average target of the training months that reach it. Colored boxes are leaves: the only values this tree can ever forecast.';
  el.append(note);
});
