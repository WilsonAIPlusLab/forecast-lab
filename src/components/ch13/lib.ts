// Chapter 13 helpers: small linear algebra (OLS, PCA), date utilities, data builders.
// Everything here runs in the browser on bundled FRED CSVs, so explorables respond instantly.
import { loadSeries, holt, type Pt } from '../../lib/ts';

export const ymKey = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
export const monthName = (d: Date, long = false) => d.toLocaleDateString('en-US', { month: long ? 'long' : 'short', year: 'numeric' });
export const dayFmt = (d: Date) => d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
export const reduceMotion = () => typeof window !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches;

/** Solve the normal equations for OLS with intercept. X: rows of predictors (no constant). */
export function ols(X: number[][], y: number[]) {
  const n = y.length, k = (X[0]?.length ?? 0) + 1;
  const A = Array.from({ length: k }, () => Array(k).fill(0));
  const b = Array(k).fill(0);
  for (let i = 0; i < n; i++) {
    const r = [1, ...X[i]];
    for (let p = 0; p < k; p++) { b[p] += r[p] * y[i]; for (let q = 0; q < k; q++) A[p][q] += r[p] * r[q]; }
  }
  const beta = solve(A, b);
  let sse = 0;
  for (let i = 0; i < n; i++) { const r = [1, ...X[i]]; const f = r.reduce((s, v, j) => s + v * beta[j], 0); sse += (y[i] - f) ** 2; }
  const sigma = Math.sqrt(sse / (n - k));
  return { beta, sigma, n, predict: (x: number[]) => [1, ...x].reduce((s, v, j) => s + v * beta[j], 0) };
}

/** Gaussian elimination with partial pivoting. */
export function solve(A: number[][], b: number[]) {
  const n = b.length, M = A.map((r, i) => [...r, b[i]]);
  for (let c = 0; c < n; c++) {
    let p = c; for (let r = c + 1; r < n; r++) if (Math.abs(M[r][c]) > Math.abs(M[p][c])) p = r;
    [M[c], M[p]] = [M[p], M[c]];
    for (let r = 0; r < n; r++) if (r !== c) { const f = M[r][c] / M[c][c]; for (let j = c; j <= n; j++) M[r][j] -= f * M[c][j]; }
  }
  return M.map((r, i) => r[n] / r[i]);
}

/** Symmetric eigen-decomposition (cyclic Jacobi). Returns eigenvalues (desc) and eigenvectors as columns. */
export function eigSym(S: number[][]) {
  const n = S.length, A = S.map((r) => r.slice());
  const V: number[][] = Array.from({ length: n }, (_, i) => Array.from({ length: n }, (_, j) => (i === j ? 1 : 0)));
  for (let sweep = 0; sweep < 60; sweep++) {
    let off = 0; for (let i = 0; i < n; i++) for (let j = i + 1; j < n; j++) off += A[i][j] ** 2;
    if (off < 1e-14) break;
    for (let p = 0; p < n; p++) for (let q = p + 1; q < n; q++) {
      if (Math.abs(A[p][q]) < 1e-15) continue;
      const th = (A[q][q] - A[p][p]) / (2 * A[p][q]);
      const t = Math.sign(th || 1) / (Math.abs(th) + Math.sqrt(th * th + 1));
      const c = 1 / Math.sqrt(t * t + 1), s = t * c;
      for (let k = 0; k < n; k++) { const akp = A[k][p], akq = A[k][q]; A[k][p] = c * akp - s * akq; A[k][q] = s * akp + c * akq; }
      for (let k = 0; k < n; k++) { const apk = A[p][k], aqk = A[q][k]; A[p][k] = c * apk - s * aqk; A[q][k] = s * apk + c * aqk; }
      for (let k = 0; k < n; k++) { const vkp = V[k][p], vkq = V[k][q]; V[k][p] = c * vkp - s * vkq; V[k][q] = s * vkp + c * vkq; }
    }
  }
  const idx = Array.from({ length: n }, (_, i) => i).sort((a, b) => A[b][b] - A[a][a]);
  return { values: idx.map((i) => A[i][i]), vectors: idx.map((i) => V.map((r) => r[i])) };
}

/** Standardize columns (sample sd), optionally clip at ±c, then PCA via the covariance of the clipped matrix (like R's prcomp). */
export function pca(X: number[][], clip: number | null) {
  const n = X.length, p = X[0].length;
  const mu = Array.from({ length: p }, (_, j) => X.reduce((s, r) => s + r[j], 0) / n);
  const sd = Array.from({ length: p }, (_, j) => Math.sqrt(X.reduce((s, r) => s + (r[j] - mu[j]) ** 2, 0) / (n - 1)));
  let Z = X.map((r) => r.map((v, j) => (v - mu[j]) / sd[j]));
  let clipped = 0;
  if (clip) Z = Z.map((r) => r.map((v) => { if (Math.abs(v) > clip) { clipped++; return Math.sign(v) * clip; } return v; }));
  const m2 = Array.from({ length: p }, (_, j) => Z.reduce((s, r) => s + r[j], 0) / n);
  const C = Array.from({ length: p }, (_, a) => Array.from({ length: p }, (_, b) => Z.reduce((s, r) => s + (r[a] - m2[a]) * (r[b] - m2[b]), 0) / (n - 1)));
  const { values, vectors } = eigSym(C);
  const tot = values.reduce((s, v) => s + v, 0);
  return { Z, values, vectors, share: values.map((v) => v / tot), clipped };
}

/** Monthly transformed series for the 20-indicator panel (same recipe as the R/Python labs). */
export const PANEL: { id: string; label: string; kind: 'growth' | 'change'; agg?: boolean; group: string }[] = [
  { id: 'PAYEMS', label: 'Payroll jobs', kind: 'growth', group: 'Labor' },
  { id: 'IANA', label: 'Iowa jobs', kind: 'growth', group: 'Labor' },
  { id: 'AWHMAN', label: 'Factory hours', kind: 'change', group: 'Labor' },
  { id: 'ICSA', label: 'Initial claims', kind: 'growth', agg: true, group: 'Labor' },
  { id: 'CCSA', label: 'Continuing claims', kind: 'growth', agg: true, group: 'Labor' },
  { id: 'INDPRO', label: 'Industrial output', kind: 'growth', group: 'Output' },
  { id: 'HOUST', label: 'Housing starts', kind: 'growth', group: 'Housing' },
  { id: 'PERMIT', label: 'Building permits', kind: 'growth', group: 'Housing' },
  { id: 'DSPIC96', label: 'Real disp. income', kind: 'growth', group: 'Income' },
  { id: 'PCE', label: 'Consumer spending', kind: 'growth', group: 'Spending' },
  { id: 'TOTALSA', label: 'Vehicle sales', kind: 'growth', group: 'Spending' },
  { id: 'RSFSXMV', label: 'Retail ex autos', kind: 'growth', group: 'Spending' },
  { id: 'RSMVPD', label: 'Auto dealers', kind: 'growth', group: 'Spending' },
  { id: 'RSFHFS', label: 'Furniture stores', kind: 'growth', group: 'Spending' },
  { id: 'RSEAS', label: 'Electronics stores', kind: 'growth', group: 'Spending' },
  { id: 'RSDBS', label: 'Building materials', kind: 'growth', group: 'Spending' },
  { id: 'RSCCAS', label: 'Clothing stores', kind: 'growth', group: 'Spending' },
  { id: 'RSFSDP', label: 'Restaurants & bars', kind: 'growth', group: 'Spending' },
  { id: 'BAA10Y', label: 'Credit spread', kind: 'change', agg: true, group: 'Finance' },
  { id: 'NFCI', label: 'Financial conditions', kind: 'change', agg: true, group: 'Finance' },
];

export async function loadPanel(start = '1993-01', end = '2026-09') {
  const raw = await Promise.all(PANEL.map((p) => loadSeries(p.id, p.agg ? { to: 'month' } : {})));
  const maps = raw.map((s, j) => {
    const m = new Map<string, number>();
    const d = s.data;
    for (let i = 1; i < d.length; i++) {
      const v = PANEL[j].kind === 'growth' ? 100 * Math.log(d[i].value / d[i - 1].value) : d[i].value - d[i - 1].value;
      // only consecutive months count as a monthly change
      const gap = (d[i].date.getFullYear() - d[i - 1].date.getFullYear()) * 12 + d[i].date.getMonth() - d[i - 1].date.getMonth();
      if (gap === 1 && Number.isFinite(v)) m.set(ymKey(d[i].date), v);
    }
    return m;
  });
  const keys: string[] = [];
  for (const k of maps[0].keys()) if (k >= start && k <= end && maps.every((m) => m.has(k))) keys.push(k);
  keys.sort();
  return { keys, dates: keys.map((k) => new Date(k + '-01T00:00:00')), X: keys.map((k) => maps.map((m) => m.get(k)!)) };
}

export async function loadRecessions() {
  const s = await loadSeries('USREC');
  const spans: { a: Date; b: Date }[] = [];
  let cur: Date | null = null;
  for (const p of s.data) {
    if (p.value === 1 && !cur) cur = p.date;
    if (p.value !== 1 && cur) { spans.push({ a: cur, b: p.date }); cur = null; }
  }
  if (cur) spans.push({ a: cur, b: s.data[s.data.length - 1].date });
  return spans;
}

export type { Pt };

// ── Retail hierarchy (Census, SA, $ millions/month) ──
// Total = Motor vehicles + Ex-autos; Ex-autos = 9 published categories + Other (the remainder, so it adds up exactly).
const CATS = [
  { k: 'Food_services', id: 'RSFSDP', label: 'Restaurants & bars' },
  { k: 'Gas', id: 'RSGASS', label: 'Gas stations' },
  { k: 'Clothing', id: 'RSCCAS', label: 'Clothing' },
  { k: 'Building', id: 'RSDBS', label: 'Building materials' },
  { k: 'Health', id: 'RSHPCS', label: 'Health & personal care' },
  { k: 'Nonstore', id: 'RSNSR', label: 'Nonstore (online)' },
  { k: 'General', id: 'RSGMS', label: 'General merchandise' },
  { k: 'Furniture', id: 'RSFHFS', label: 'Furniture' },
  { k: 'Electronics', id: 'RSEAS', label: 'Electronics' },
];
const BOTTOM = ['Motor_vehicles', ...CATS.map((c) => c.k), 'Other'];
const NODES = ['Total', 'Ex_autos', ...BOTTOM];
const LABEL: Record<string, string> = { Total: 'Total retail & food', Ex_autos: 'Everything but autos', Motor_vehicles: 'Motor vehicles & parts', Other: 'Other (grocery, sporting…)', ...Object.fromEntries(CATS.map((c) => [c.k, c.label])) };
const METHODS = [
  { k: 'base', label: 'Base (independent)' },
  { k: 'bu', label: 'Bottom-up' },
  { k: 'td', label: 'Top-down' },
  { k: 'ols', label: 'OLS reconcile' },
  { k: 'wls', label: 'WLS reconcile' },
] as const;
const H = 12;
export const HIER = { CATS, BOTTOM, NODES, LABEL, METHODS, H };
type MK = (typeof METHODS)[number]['k'];
// summing matrix S (13 x 11)
const S: number[][] = NODES.map((n) => BOTTOM.map((b): number => (n === 'Total' ? 1 : n === 'Ex_autos' ? (b === 'Motor_vehicles' ? 0 : 1) : n === b ? 1 : 0)));

/** Damped Holt with a small grid search on in-sample one-step squared error (a JS stand-in for ets()). */
function fitHolt(y: number[]) {
  let best = { sse: Infinity, a: 0.5, b: 0.1, p: 1 };
  for (const a of [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1]) for (const b of [0.01, 0.05, 0.1, 0.2]) for (const p of [0.8, 0.9, 0.95, 0.98, 1]) {
    const { fitted } = holt(y, a, b, 0, p);
    let sse = 0; for (let i = 2; i < y.length; i++) sse += (y[i] - fitted[i]) ** 2;
    if (sse < best.sse) best = { sse, a, b, p };
  }
  return holt(y, best.a, best.b, H, best.p).forecast;
}
const mul = (A: number[][], B: number[][]) => A.map((r) => B[0].map((_, j) => r.reduce((s, v, k) => s + v * B[k][j], 0)));
const tr = (A: number[][]) => A[0].map((_, j) => A.map((r) => r[j]));

export async function hierarchyForecasts() {
  const ser = await Promise.all(['RSAFS', 'RSFSXMV', 'RSMVPD', ...CATS.map((c) => c.id)].map((id) => loadSeries(id, { start: '2015-01-01' })));
  const n = Math.min(...ser.map((s) => s.data.length));
  const v = ser.map((s) => s.data.slice(0, n).map((p) => p.value));
  const dates = ser[0].data.slice(0, n).map((p) => p.date);
  const other = v[1].map((x, i) => x - CATS.reduce((s, _, j) => s + v[3 + j][i], 0));
  const Y: Record<string, number[]> = { Total: v[0], Ex_autos: v[1], Motor_vehicles: v[2], Other: other };
  CATS.forEach((c, j) => (Y[c.k] = v[3 + j]));
  const nt = n - H;
  const base: Record<string, number[]> = {};
  for (const k of NODES) base[k] = fitHolt(Y[k].slice(0, nt));
  const act: Record<string, number[]> = Object.fromEntries(NODES.map((k) => [k, Y[k].slice(nt)]));
  const fromBottom = (bot: Record<string, number[]>) => { const o: Record<string, number[]> = {}; NODES.forEach((nd, i) => (o[nd] = Array.from({ length: H }, (_, h) => BOTTOM.reduce((s, b, j) => s + S[i][j] * bot[b][h], 0)))); return o; };
  const bu = fromBottom(base);
  const share = Object.fromEntries(BOTTOM.map((b) => [b, Array.from({ length: 12 }, (_, i) => Y[b][nt - 12 + i] / Y.Total[nt - 12 + i]).reduce((s, x) => s + x, 0) / 12]));
  const td = fromBottom(Object.fromEntries(BOTTOM.map((b) => [b, base.Total.map((t) => t * share[b])])));
  const reconcile = (w: number[]) => {
    // bottom = (S' W^-1 S)^-1 S' W^-1 yhat, then S * bottom
    const Wi = w.map((x) => 1 / x);
    const StWi = tr(S).map((r) => r.map((val, i) => val * Wi[i]));
    const A = mul(StWi, S);
    const out: Record<string, number[]> = Object.fromEntries(BOTTOM.map((b) => [b, [] as number[]]));
    for (let h = 0; h < H; h++) {
      const rhs = StWi.map((r) => r.reduce((s, val, i) => s + val * base[NODES[i]][h], 0));
      const bt = solve(A, rhs);
      BOTTOM.forEach((b, j) => out[b].push(bt[j]));
    }
    return fromBottom(out);
  };
  const ols = reconcile(NODES.map(() => 1));
  const wls = reconcile(S.map((r) => r.reduce((s, x) => s + x, 0)));
  const F: Record<MK, Record<string, number[]>> = { base, bu, td, ols, wls };
  const mape = (f: Record<string, number[]>, k: string) => (100 * act[k].reduce((s, a, h) => s + Math.abs(a - f[k][h]) / a, 0)) / H;
  const score = Object.fromEntries(METHODS.map((m) => [m.k, { total: mape(F[m.k], 'Total'), ex: mape(F[m.k], 'Ex_autos'), bot: BOTTOM.reduce((s, b) => s + mape(F[m.k], b), 0) / BOTTOM.length }])) as Record<MK, { total: number; ex: number; bot: number }>;
  const gap = Object.fromEntries(METHODS.map((m) => [m.k, Array.from({ length: H }, (_, h) => F[m.k].Total[h] - BOTTOM.reduce((s, b) => s + F[m.k][b][h], 0))])) as Record<MK, number[]>;
  return { F, act, score, gap, testDates: dates.slice(nt), lastTrain: dates[nt - 1] };
}
