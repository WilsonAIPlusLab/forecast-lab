// Tiny gradient-boosting engine (squared loss, depth-limited regression trees) for the
// "Boosting, one tree at a time" explorable. Pure functions, no DOM: runs in the browser and in Node.

export interface Pt { date: Date; value: number }
export interface Row { date: Date; sales: number; lag1: number; growth: number; x: number[] }

export const FEATURES = [
  { k: 'month', label: 'calendar month', fmt: (v: number) => ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][v - 1] },
  { k: 'growth_ly', label: 'same month last year’s growth', fmt: (v: number) => v.toFixed(1) + '%' },
  { k: 'growth_lm', label: 'last month’s growth', fmt: (v: number) => v.toFixed(1) + '%' },
  { k: 'yoy_lm', label: 'last month’s year-over-year growth', fmt: (v: number) => v.toFixed(1) + '%' },
  { k: 'weekend', label: 'weekend days in the month', fmt: (v: number) => v.toFixed(0) },
];

export function weekendDays(d: Date): number {
  const y = d.getFullYear(), m = d.getMonth();
  const n = new Date(y, m + 1, 0).getDate();
  let c = 0;
  for (let k = 1; k <= n; k++) { const w = new Date(y, m, k).getDay(); if (w === 0 || w === 6) c++; }
  return c;
}

/** Supervised table: target = month-over-month growth in %, features known before the month starts. */
export function buildTable(data: Pt[]): Row[] {
  const v = data.map((p) => p.value);
  const g = v.map((x, i) => (i ? 100 * (x / v[i - 1] - 1) : NaN));
  const rows: Row[] = [];
  for (let i = 13; i < data.length; i++) {
    rows.push({
      date: data[i].date, sales: v[i], lag1: v[i - 1], growth: g[i],
      x: [data[i].date.getMonth() + 1, g[i - 12], g[i - 1], 100 * (v[i - 1] / v[i - 13] - 1), weekendDays(data[i].date)],
    });
  }
  return rows;
}

export type Node = { leaf: true; value: number; n: number } | { leaf: false; f: number; thr: number; left: Node; right: Node; n: number };

/** Exact greedy regression tree on residuals r (squared loss, L2 penalty lambda on leaf weights, like XGBoost). */
export function fitTree(X: number[][], r: number[], idx: number[], depth: number, minLeaf = 5, lambda = 1): Node {
  const leafVal = (ii: number[]) => ii.reduce((s, i) => s + r[i], 0) / (ii.length + lambda);
  if (depth === 0 || idx.length < 2 * minLeaf) return { leaf: true, value: leafVal(idx), n: idx.length };
  let best = { gain: 1e-9, f: -1, thr: 0 };
  const G = idx.reduce((s, i) => s + r[i], 0), N = idx.length;
  const parent = (G * G) / (N + lambda);
  for (let f = 0; f < X[0].length; f++) {
    const s = [...idx].sort((a, b) => X[a][f] - X[b][f]);
    let gl = 0;
    for (let j = 0; j < N - 1; j++) {
      gl += r[s[j]];
      const nl = j + 1;
      if (nl < minLeaf || N - nl < minLeaf) continue;
      const a = X[s[j]][f], b = X[s[j + 1]][f];
      if (a === b) continue;
      const gr = G - gl;
      const gain = (gl * gl) / (nl + lambda) + (gr * gr) / (N - nl + lambda) - parent;
      if (gain > best.gain) best = { gain, f, thr: (a + b) / 2 };
    }
  }
  if (best.f < 0) return { leaf: true, value: leafVal(idx), n: idx.length };
  const L = idx.filter((i) => X[i][best.f] <= best.thr), R = idx.filter((i) => X[i][best.f] > best.thr);
  return { leaf: false, f: best.f, thr: best.thr, n: N, left: fitTree(X, r, L, depth - 1, minLeaf, lambda), right: fitTree(X, r, R, depth - 1, minLeaf, lambda) };
}

export const predictTree = (t: Node, x: number[]): number => (t.leaf ? t.value : predictTree(x[t.f] <= t.thr ? t.left : t.right, x));

export interface BoostRun {
  rounds: number; eta: number; depth: number; base: number;
  trees: Node[];
  /** pred[k][i] = predicted growth (%) for row i after k trees */
  pred: Float64Array[];
  trainRMSE: number[]; testRMSE: number[];   // in $ (same units as sales)
}

/** Boost `rounds` trees. isTrain[i] marks training rows; the rest are held out. */
export function boost(rows: Row[], isTrain: boolean[], eta: number, depth: number, rounds: number): BoostRun {
  const X = rows.map((r) => r.x), y = rows.map((r) => r.growth);
  const tr = rows.map((_, i) => i).filter((i) => isTrain[i]);
  const base = tr.reduce((s, i) => s + y[i], 0) / tr.length;
  let F = new Float64Array(rows.length).fill(base);
  const pred = [F.slice()], trees: Node[] = [];
  const rmse = (F: Float64Array, which: boolean) => {
    let s = 0, n = 0;
    rows.forEach((r, i) => { if (isTrain[i] === which) { const e = r.sales - r.lag1 * (1 + F[i] / 100); s += e * e; n++; } });
    return Math.sqrt(s / n);
  };
  const trainRMSE = [rmse(F, true)], testRMSE = [rmse(F, false)];
  for (let k = 0; k < rounds; k++) {
    const res = y.map((v, i) => v - F[i]);
    const t = fitTree(X, res, tr, depth);
    trees.push(t);
    const G = new Float64Array(rows.length);
    for (let i = 0; i < rows.length; i++) G[i] = F[i] + eta * predictTree(t, X[i]);
    F = G; pred.push(F.slice());
    trainRMSE.push(rmse(F, true)); testRMSE.push(rmse(F, false));
  }
  return { rounds, eta, depth, base, trees, pred, trainRMSE, testRMSE };
}

/** Plain-English rules of one tree: one line per leaf, with conditions on the same feature merged. */
export function treeRules(t: Node, bounds: Record<number, [number, number]> = {}): { rule: string; value: number; n: number }[] {
  if (t.leaf) {
    const parts = Object.entries(bounds).map(([fs, [lo, hi]]) => {
      const F = FEATURES[+fs];
      if (F.k === 'month') {
        const a = Math.floor(lo) + 1, b = Math.floor(hi);
        const A = F.fmt(Math.max(1, a)), B = F.fmt(Math.min(12, b));
        return a === b ? `month is ${A}` : `month is ${A}–${B}`;
      }
      const f = (v: number) => (F.k === 'weekend' ? String(Math.floor(v)) : F.fmt(v));
      if (lo === -Infinity) return `${F.label} ≤ ${f(hi)}`;
      if (hi === Infinity) return `${F.label} > ${f(lo)}`;
      return `${F.label} between ${f(lo)} and ${f(hi)}`;
    });
    return [{ rule: parts.length ? parts.join(', ') : 'every month', value: t.value, n: t.n }];
  }
  const [lo, hi] = bounds[t.f] ?? (FEATURES[t.f].k === 'month' ? [0, 12] : [-Infinity, Infinity]);
  return [
    ...treeRules(t.left, { ...bounds, [t.f]: [lo, Math.min(hi, t.thr)] }),
    ...treeRules(t.right, { ...bounds, [t.f]: [Math.max(lo, t.thr), hi] }),
  ];
}
