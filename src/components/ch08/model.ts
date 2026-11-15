// Chapter 8 shared data + binary-outcome toolkit (pure JS, instant).
// Mirrors the labs: spread = GS10 − TB3MS (monthly averages, pct. points), target = USREC at t + 12.
import { loadSeries } from '../../lib/ts';

export interface Row { date: Date; spread: number; rec: number; ahead: number | null; target: Date }

let cache: Promise<Row[]> | null = null;
/** Monthly rows from Jan 1959. `ahead` = recession indicator 12 months later (null when not yet known). */
export function loadRecData(): Promise<Row[]> {
  if (!cache) cache = (async () => {
    const [g, t, u] = await Promise.all([loadSeries('GS10', { start: '1959-01-01' }), loadSeries('TB3MS', { start: '1959-01-01' }), loadSeries('USREC', { start: '1959-01-01' })]);
    const key = (d: Date) => `${d.getFullYear()}-${d.getMonth()}`;
    const tb = new Map(t.data.map((p) => [key(p.date), p.value]));
    const us = new Map(u.data.map((p) => [key(p.date), p.value]));
    const rows: Row[] = [];
    for (const p of g.data) {
      const b = tb.get(key(p.date)), r = us.get(key(p.date));
      if (b == null || r == null) continue;
      const target = new Date(p.date); target.setMonth(target.getMonth() + 12);
      rows.push({ date: p.date, spread: +(p.value - b).toFixed(4), rec: r, ahead: null, target });
    }
    rows.forEach((row, i) => { row.ahead = i + 12 < rows.length ? rows[i + 12].rec : null; });
    return rows;
  })();
  return cache;
}

/** Recession months (1 = recession) as [start, end) date ranges, for shading. */
export async function recessionSpans(): Promise<{ a: Date; b: Date }[]> {
  const u = await loadSeries('USREC', { start: '1959-01-01' });
  const out: { a: Date; b: Date }[] = [];
  let a: Date | null = null;
  u.data.forEach((p, i) => {
    if (p.value === 1 && !a) a = p.date;
    const next = u.data[i + 1];
    if (a && (p.value === 0 || !next)) { const b = p.value === 0 ? p.date : new Date(p.date.getFullYear(), p.date.getMonth() + 1, 1); out.push({ a, b }); a = null; }
  });
  return out;
}

export const sigmoid = (z: number) => 1 / (1 + Math.exp(-z));

export function logLik(a: number, b: number, x: number[], y: number[]) {
  let ll = 0;
  for (let i = 0; i < x.length; i++) { const p = Math.min(1 - 1e-12, Math.max(1e-12, sigmoid(a + b * x[i]))); ll += y[i] ? Math.log(p) : Math.log(1 - p); }
  return ll;
}

/** Logistic regression of y on one predictor by Newton–Raphson (= IRLS, what glm() does). */
export function fitLogit(x: number[], y: number[], iters = 50) {
  let a = 0, b = 0;
  for (let k = 0; k < iters; k++) {
    let g0 = 0, g1 = 0, h00 = 0, h01 = 0, h11 = 0;
    for (let i = 0; i < x.length; i++) {
      const p = sigmoid(a + b * x[i]), w = p * (1 - p), e = y[i] - p;
      g0 += e; g1 += e * x[i]; h00 += w; h01 += w * x[i]; h11 += w * x[i] * x[i];
    }
    const det = h00 * h11 - h01 * h01;
    const da = (h11 * g0 - h01 * g1) / det, db = (h00 * g1 - h01 * g0) / det;
    a += da; b += db;
    if (Math.abs(da) + Math.abs(db) < 1e-10) break;
  }
  return { a, b, ll: logLik(a, b, x, y) };
}

/** Ordinary least squares line (the linear probability model). */
export function fitLine(x: number[], y: number[]) {
  const n = x.length, mx = x.reduce((s, v) => s + v, 0) / n, my = y.reduce((s, v) => s + v, 0) / n;
  let sxy = 0, sxx = 0;
  for (let i = 0; i < n; i++) { sxy += (x[i] - mx) * (y[i] - my); sxx += (x[i] - mx) ** 2; }
  const b = sxy / sxx; return { a: my - b * mx, b };
}

/** AUC via the rank (Mann–Whitney) formula, with average ranks for ties. */
export function auc(p: number[], y: number[]) {
  const idx = p.map((v, i) => [v, i] as [number, number]).sort((u, v) => u[0] - v[0]);
  const rank = new Array(p.length);
  for (let i = 0; i < idx.length;) {
    let j = i; while (j + 1 < idx.length && idx[j + 1][0] === idx[i][0]) j++;
    for (let k = i; k <= j; k++) rank[idx[k][1]] = (i + j) / 2 + 1;
    i = j + 1;
  }
  let n1 = 0, s = 0;
  y.forEach((v, i) => { if (v) { n1++; s += rank[i]; } });
  const n0 = y.length - n1;
  return (s - (n1 * (n1 + 1)) / 2) / (n1 * n0);
}

/** ROC points for every threshold, from (0,0) to (1,1). */
export function rocCurve(p: number[], y: number[]) {
  const th = [Infinity, ...[...new Set(p)].sort((u, v) => v - u), -Infinity];
  const n1 = y.filter(Boolean).length, n0 = y.length - n1;
  return th.map((t) => {
    let tp = 0, fp = 0;
    for (let i = 0; i < p.length; i++) if (p[i] >= t) { if (y[i]) tp++; else fp++; }
    return { t, tpr: tp / n1, fpr: fp / n0 };
  });
}

export function confusion(p: number[], y: number[], t: number) {
  let tp = 0, fp = 0, fn = 0, tn = 0;
  for (let i = 0; i < p.length; i++) { const c = p[i] >= t; if (c && y[i]) tp++; else if (c) fp++; else if (y[i]) fn++; else tn++; }
  return { tp, fp, fn, tn, hit: tp / Math.max(1, tp + fn), fa: fp / Math.max(1, fp + tn) };
}

export const brier = (p: number[], y: number[]) => p.reduce((s, v, i) => s + (v - y[i]) ** 2, 0) / p.length;

/** Two ready-made forecast sets used by several explorables. */
export async function forecastSets() {
  const rows = await loadRecData();
  const known = rows.filter((r) => r.ahead !== null);
  const full = fitLogit(known.map((r) => r.spread), known.map((r) => r.ahead!));
  const train = known.filter((r) => r.date.getFullYear() <= 1999);
  const rt = fitLogit(train.map((r) => r.spread), train.map((r) => r.ahead!));
  const test = known.filter((r) => r.date.getFullYear() >= 2000);
  const mk = (rs: Row[], m: { a: number; b: number }) => ({ rows: rs, p: rs.map((r) => sigmoid(m.a + m.b * r.spread)), y: rs.map((r) => r.ahead!) });
  return {
    rows, known, full, rt,
    sets: {
      insample: { label: 'In sample, 1959–2025', ...mk(known, full), base: known.reduce((s, r) => s + r.ahead!, 0) / known.length },
      oos: { label: 'Out of sample, 2000–2025', ...mk(test, rt), base: train.reduce((s, r) => s + r.ahead!, 0) / train.length },
    },
  };
}

export const mon = (d: Date) => d.toLocaleDateString('en-US', { year: 'numeric', month: 'short' });
export const pct = (v: number, d = 0) => `${(100 * v).toFixed(d)}%`;
