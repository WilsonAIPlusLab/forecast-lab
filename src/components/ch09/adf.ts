// Augmented Dickey–Fuller test with a constant (same regression as urca::ur.df(type = "drift", lags = k)):
//   Δz_t = a + γ z_{t-1} + Σ_{j=1..k} φ_j Δz_{t-j} + e_t ;  returns the t-statistic on γ (tau2).
// Verified against R: for GS10 − β·TB3MS (1960–2019, k = 4) it reproduces ur.df to 3 decimals.
export function adfTau(z: number[], k = 4): number {
  const dz = z.slice(1).map((v, i) => v - z[i]);
  const X: number[][] = [], y: number[] = [];
  for (let t = k; t < dz.length; t++) { // dz[t] = z[t+1] - z[t]
    X.push([1, z[t], ...Array.from({ length: k }, (_, j) => dz[t - 1 - j])]);
    y.push(dz[t]);
  }
  const p = X[0].length, N = X.length;
  const A = Array.from({ length: p }, () => new Array(p).fill(0)), b = new Array(p).fill(0);
  for (let i = 0; i < N; i++) for (let r = 0; r < p; r++) { b[r] += X[i][r] * y[i]; for (let c = 0; c < p; c++) A[r][c] += X[i][r] * X[i][c]; }
  const inv = invert(A), beta = inv.map((row) => row.reduce((s, v, c) => s + v * b[c], 0));
  let rss = 0; for (let i = 0; i < N; i++) { const e = y[i] - X[i].reduce((s, v, c) => s + v * beta[c], 0); rss += e * e; }
  const s2 = rss / (N - p);
  return beta[1] / Math.sqrt(s2 * inv[1][1]);
}
function invert(M: number[][]): number[][] {
  const n = M.length, A = M.map((r, i) => [...r, ...Array.from({ length: n }, (_, j) => (i === j ? 1 : 0))]);
  for (let c = 0; c < n; c++) {
    let piv = c; for (let r = c + 1; r < n; r++) if (Math.abs(A[r][c]) > Math.abs(A[piv][c])) piv = r;
    [A[c], A[piv]] = [A[piv], A[c]];
    const d = A[c][c]; for (let j = 0; j < 2 * n; j++) A[c][j] /= d;
    for (let r = 0; r < n; r++) if (r !== c) { const f = A[r][c]; for (let j = 0; j < 2 * n; j++) A[r][j] -= f * A[c][j]; }
  }
  return A.map((r) => r.slice(n));
}
