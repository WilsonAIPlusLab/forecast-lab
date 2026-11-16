// Small numerical helpers for the Chapter 8 explorables (pure JS, instant).
import type { Pt } from '../../lib/ts';

export const key = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;

/** 100 × log change over `lag` periods (≈ % change), on a monthly series. */
export function logDiff(data: Pt[], lag: number): Pt[] {
  const out: Pt[] = [];
  for (let i = lag; i < data.length; i++) out.push({ date: data[i].date, value: 100 * Math.log(data[i].value / data[i - lag].value) });
  return out;
}
export function diff(data: Pt[]): Pt[] {
  return data.slice(1).map((p, i) => ({ date: p.date, value: p.value - data[i].value }));
}
export const between = (d: Pt[], from: string, to: string) => d.filter((p) => key(p.date) >= from && key(p.date) <= to);

/** Cross-correlation exactly as R's ccf(): cor(x[t+k], y[t]) using full-sample means and sds (divide by n). */
export function ccf(x: number[], y: number[], k: number) {
  const n = x.length;
  const mx = x.reduce((a, b) => a + b, 0) / n, my = y.reduce((a, b) => a + b, 0) / n;
  const sx = Math.sqrt(x.reduce((a, b) => a + (b - mx) ** 2, 0) / n), sy = Math.sqrt(y.reduce((a, b) => a + (b - my) ** 2, 0) / n);
  let s = 0;
  for (let t = 0; t < n; t++) { const j = t + k; if (j >= 0 && j < n) s += (x[j] - mx) * (y[t] - my); }
  return s / n / (sx * sy);
}

export const zscore = (v: number[]) => {
  const n = v.length, m = v.reduce((a, b) => a + b, 0) / n;
  const s = Math.sqrt(v.reduce((a, b) => a + (b - m) ** 2, 0) / (n - 1));
  return v.map((x) => (x - m) / s);
};

/** OLS via normal equations (Gauss–Jordan with partial pivoting). X rows include the intercept column. */
export function ols(X: number[][], y: number[]) {
  const k = X[0].length, n = X.length;
  const A = Array.from({ length: k }, () => new Array(k + 1).fill(0));
  for (let i = 0; i < n; i++) for (let a = 0; a < k; a++) { A[a][k] += X[i][a] * y[i]; for (let b = 0; b < k; b++) A[a][b] += X[i][a] * X[i][b]; }
  for (let c = 0; c < k; c++) {
    let p = c; for (let r = c + 1; r < k; r++) if (Math.abs(A[r][c]) > Math.abs(A[p][c])) p = r;
    [A[c], A[p]] = [A[p], A[c]];
    const d = A[c][c] || 1e-12;
    for (let j = c; j <= k; j++) A[c][j] /= d;
    for (let r = 0; r < k; r++) if (r !== c) { const f = A[r][c]; if (f) for (let j = c; j <= k; j++) A[r][j] -= f * A[c][j]; }
  }
  const beta = A.map((row) => row[k]);
  let rss = 0; for (let i = 0; i < n; i++) { let f = 0; for (let a = 0; a < k; a++) f += X[i][a] * beta[a]; rss += (y[i] - f) ** 2; }
  return { beta, rss, n, k };
}

export const mean = (v: number[]) => v.reduce((a, b) => a + b, 0) / v.length;
export const ymLabel = (d: Date) => d.toLocaleDateString('en-US', { year: 'numeric', month: 'short' });

/** Pearson correlation (same as R's cor() for two numeric vectors). */
export function corr(x: number[], y: number[]) {
  const n = x.length, mx = mean(x), my = mean(y);
  let sxy = 0, sxx = 0, syy = 0;
  for (let i = 0; i < n; i++) { sxy += (x[i] - mx) * (y[i] - my); sxx += (x[i] - mx) ** 2; syy += (y[i] - my) ** 2; }
  return sxy / Math.sqrt(sxx * syy);
}
