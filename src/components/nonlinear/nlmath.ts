// Small numerical toolkit for Chapter 5 explorables: CSV parsing, design matrices,
// least squares (Householder QR), logistic regression by IRLS (the algorithm R's glm() uses), AUC.
// Verified against R 4.4 glm()/lm() on the bank-marketing data (see src/labs/nonlinear/make_data.R).

export type Row = Record<string, string | number>;

/** Parse a simple CSV (no quoted commas) into objects; numeric-looking fields become numbers. */
export function parseCSV(text: string): Row[] {
  const lines = text.trim().split(/\r?\n/);
  const head = lines[0].split(',').map((h) => h.replace(/^"|"$/g, ''));
  return lines.slice(1).map((l) => {
    const v = l.split(',');
    const o: Row = {};
    head.forEach((h, i) => {
      const s = (v[i] ?? '').replace(/^"|"$/g, '');
      const n = Number(s);
      o[h] = s !== '' && Number.isFinite(n) ? n : s;
    });
    return o;
  });
}

export interface Term { name: string; cat?: boolean; ref?: string }
export interface Design { X: number[][]; cols: string[] }

/** Build a model matrix with an intercept. Categorical terms get treatment (dummy) coding:
 *  levels sorted alphabetically like R's factor(), first level (or `ref`) is the baseline. */
export function design(rows: Row[], terms: Term[]): Design {
  const cols = ['(Intercept)'];
  const makers: ((r: Row) => number[])[] = [];
  for (const t of terms) {
    if (t.cat) {
      let lv = [...new Set(rows.map((r) => String(r[t.name])))].sort();
      if (t.ref) lv = [t.ref, ...lv.filter((l) => l !== t.ref)];
      const keep = lv.slice(1);
      keep.forEach((l) => cols.push(t.name + l));
      makers.push((r) => keep.map((l) => (String(r[t.name]) === l ? 1 : 0)));
    } else {
      cols.push(t.name);
      makers.push((r) => [Number(r[t.name])]);
    }
  }
  const X = rows.map((r) => [1, ...makers.flatMap((m) => m(r))]);
  return { X, cols };
}

/** Weighted least squares via Householder QR: minimises sum w_i (z_i - x_i b)^2.
 *  Columns that are (numerically) linear combinations of earlier ones are dropped first, with
 *  R's lm()/glm() relative tolerance of 1e-7, and get coefficient 0 (R reports NA). */
export function nonAliased(X: number[][]): number[] {
  const n = X.length, P = X[0].length;
  const Q: number[][] = [], keep: number[] = [];
  for (let j = 0; j < P; j++) {
    const v = X.map((r) => r[j]);
    const n0 = Math.sqrt(v.reduce((s, x) => s + x * x, 0));
    for (const q of Q) { const d = v.reduce((s, x, i) => s + x * q[i], 0); for (let i = 0; i < n; i++) v[i] -= d * q[i]; }
    const n1 = Math.sqrt(v.reduce((s, x) => s + x * x, 0));
    if (n0 > 0 && n1 > 1e-7 * n0) { Q.push(v.map((x) => x / n1)); keep.push(j); }
  }
  return keep;
}

export function wls(X: number[][], z: number[], w?: number[], keep: number[] = nonAliased(X)): number[] {
  const n = X.length, P = X[0].length;
  const sw = (i: number) => (w ? Math.sqrt(w[i]) : 1);
  // 2. Householder QR on the kept columns
  const p = keep.length;
  const A = X.map((r, i) => keep.map((j) => r[j] * sw(i)));
  const b = z.map((v, i) => v * sw(i));
  for (let k = 0; k < p; k++) {
    let norm = 0;
    for (let i = k; i < n; i++) norm += A[i][k] * A[i][k];
    norm = Math.sqrt(norm);
    const alpha = A[k][k] > 0 ? -norm : norm;
    const v = new Array(n).fill(0);
    v[k] = A[k][k] - alpha;
    for (let i = k + 1; i < n; i++) v[i] = A[i][k];
    let vv = 0; for (let i = k; i < n; i++) vv += v[i] * v[i];
    if (vv === 0) continue;
    for (let j = k; j < p; j++) {
      let s = 0; for (let i = k; i < n; i++) s += v[i] * A[i][j];
      const f = (2 * s) / vv; for (let i = k; i < n; i++) A[i][j] -= f * v[i];
    }
    let s = 0; for (let i = k; i < n; i++) s += v[i] * b[i];
    const f = (2 * s) / vv; for (let i = k; i < n; i++) b[i] -= f * v[i];
  }
  const bk = new Array(p).fill(0);
  for (let k = p - 1; k >= 0; k--) {
    let s = b[k];
    for (let j = k + 1; j < p; j++) s -= A[k][j] * bk[j];
    bk[k] = s / A[k][k];
  }
  const beta = new Array(P).fill(0);
  keep.forEach((j, k) => (beta[j] = bk[k]));
  return beta;
}

export const dot = (a: number[], b: number[]) => a.reduce((s, v, i) => s + v * b[i], 0);
export const plogis = (x: number) => 1 / (1 + Math.exp(-x));

/** Logistic regression by iteratively reweighted least squares, with glm()'s convergence rule. */
export function logit(X: number[][], y: number[], maxit = 25) {
  const n = y.length;
  let mu = y.map((v) => (v + 0.5) / 2); // glm's binomial starting values
  let eta = mu.map((m) => Math.log(m / (1 - m)));
  let beta: number[] = [];
  let devOld = Infinity, dev = 0, iter = 0;
  const keep = nonAliased(X);
  for (iter = 1; iter <= maxit; iter++) {
    const w = mu.map((m) => Math.max(m * (1 - m), 1e-12));
    const z = eta.map((e, i) => e + (y[i] - mu[i]) / w[i]);
    beta = wls(X, z, w, keep);
    eta = X.map((r) => dot(r, beta));
    mu = eta.map((e) => Math.min(1 - 2.22e-16, Math.max(2.22e-16, plogis(e))));
    dev = -2 * y.reduce((s, v, i) => s + (v ? Math.log(mu[i]) : Math.log(1 - mu[i])), 0);
    if (Math.abs(dev - devOld) / (Math.abs(dev) + 0.1) < 1e-8) break;
    devOld = dev;
  }
  return { beta, p: mu, deviance: dev, iter };
}

/** OLS fit: coefficients and fitted values. */
export function ols(X: number[][], y: number[]) {
  const beta = wls(X, y, undefined, nonAliased(X));
  return { beta, fitted: X.map((r) => dot(r, beta)) };
}

/** AUC = probability a random positive outranks a random negative (ties count one half). */
export function auc(p: number[], y: number[]) {
  const idx = p.map((_, i) => i).sort((a, b) => p[a] - p[b]);
  const rank = new Array(p.length);
  for (let i = 0; i < idx.length;) {
    let j = i; while (j + 1 < idx.length && p[idx[j + 1]] === p[idx[i]]) j++;
    const r = (i + j) / 2 + 1; for (let k = i; k <= j; k++) rank[idx[k]] = r; i = j + 1;
  }
  const n1 = y.reduce((s, v) => s + v, 0), n0 = y.length - n1;
  const s1 = y.reduce((s, v, i) => s + (v ? rank[i] : 0), 0);
  return (s1 - (n1 * (n1 + 1)) / 2) / (n1 * n0);
}

/** Fetch and parse a bundled CSV once per page. */
const cache: Record<string, Promise<Row[]>> = {};
export function loadCSV(base: string, file: string): Promise<Row[]> {
  return (cache[file] ??= fetch(`${base}data/${file}`).then((r) => r.text()).then(parseCSV));
}
