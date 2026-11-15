// Small, numerically stable OLS for the Chapter 4 explorables (Householder QR).
// X: n rows × p columns (include a column of 1s yourself for an intercept).
export interface OLS { beta: number[]; fitted: number[]; resid: number[]; sse: number; r2: number; sigma: number; XtXinv: number[][]; n: number; p: number }

export function ols(X: number[][], y: number[]): OLS {
  const n = X.length, p = X[0].length;
  const A = X.map((r) => r.slice());
  const b = y.slice();
  const R: number[][] = Array.from({ length: p }, () => Array(p).fill(0));
  for (let k = 0; k < p; k++) {
    let norm = 0;
    for (let i = k; i < n; i++) norm += A[i][k] * A[i][k];
    norm = Math.sqrt(norm);
    if (norm === 0) continue;
    const alpha = A[k][k] > 0 ? -norm : norm;
    const v = Array(n).fill(0);
    for (let i = k; i < n; i++) v[i] = A[i][k];
    v[k] -= alpha;
    let vv = 0;
    for (let i = k; i < n; i++) vv += v[i] * v[i];
    if (vv === 0) continue;
    for (let j = k; j < p; j++) {
      let s = 0;
      for (let i = k; i < n; i++) s += v[i] * A[i][j];
      const f = (2 * s) / vv;
      for (let i = k; i < n; i++) A[i][j] -= f * v[i];
    }
    let s = 0;
    for (let i = k; i < n; i++) s += v[i] * b[i];
    const f = (2 * s) / vv;
    for (let i = k; i < n; i++) b[i] -= f * v[i];
  }
  for (let i = 0; i < p; i++) for (let j = i; j < p; j++) R[i][j] = A[i][j];
  const beta = Array(p).fill(0);
  for (let i = p - 1; i >= 0; i--) {
    let s = b[i];
    for (let j = i + 1; j < p; j++) s -= R[i][j] * beta[j];
    beta[i] = s / R[i][i];
  }
  // R^-1 (upper triangular), then (X'X)^-1 = R^-1 R^-T
  const Ri: number[][] = Array.from({ length: p }, () => Array(p).fill(0));
  for (let j = 0; j < p; j++) {
    Ri[j][j] = 1 / R[j][j];
    for (let i = j - 1; i >= 0; i--) {
      let s = 0;
      for (let k = i + 1; k <= j; k++) s += R[i][k] * Ri[k][j];
      Ri[i][j] = -s / R[i][i];
    }
  }
  const XtXinv = Array.from({ length: p }, (_, i) => Array.from({ length: p }, (_, j) => { let s = 0; for (let k = Math.max(i, j); k < p; k++) s += Ri[i][k] * Ri[j][k]; return s; }));
  const fitted = X.map((r) => r.reduce((s, x, j) => s + x * beta[j], 0));
  const resid = y.map((v, i) => v - fitted[i]);
  const sse = resid.reduce((s, e) => s + e * e, 0);
  const ybar = y.reduce((s, v) => s + v, 0) / n;
  const sst = y.reduce((s, v) => s + (v - ybar) ** 2, 0);
  return { beta, fitted, resid, sse, r2: 1 - sse / sst, sigma: Math.sqrt(sse / (n - p)), XtXinv, n, p };
}

export const predict = (beta: number[], x: number[]) => x.reduce((s, v, j) => s + v * beta[j], 0);

/** Standard error of a new observation at x0: sigma * sqrt(1 + x0' (X'X)^-1 x0). */
export function predSE(fit: OLS, x0: number[]) {
  let q = 0;
  for (let i = 0; i < fit.p; i++) for (let j = 0; j < fit.p; j++) q += x0[i] * fit.XtXinv[i][j] * x0[j];
  return fit.sigma * Math.sqrt(1 + q);
}

/** Join several monthly series on their dates (YYYY-MM keys). */
export function joinMonthly(series: { date: Date; value: number }[][]) {
  const key = (d: Date) => `${d.getFullYear()}-${d.getMonth()}`;
  const maps = series.map((s) => new Map(s.map((p) => [key(p.date), p.value])));
  return series[0].filter((p) => maps.every((m) => Number.isFinite(m.get(key(p.date))))).map((p) => ({ date: p.date, v: maps.map((m) => m.get(key(p.date))!) }));
}

/** Two-sided t critical value for 95% at large df (normal approx, with a small-sample correction). */
export const t975 = (df: number) => 1.959964 + 2.37228 / df + 2.82202 / (df * df);
