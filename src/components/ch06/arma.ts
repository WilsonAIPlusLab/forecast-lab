// Small ARMA toolkit for the Chapter 7 explorables (pure JS, instant).
import { rng } from '../../lib/ts';

/** psi-weights of the MA(infinity) representation of an ARMA(p,q): y_t = sum psi_j e_{t-j}. */
export function psiWeights(phi: number[], theta: number[], n = 600): number[] {
  const psi = new Array(n).fill(0);
  psi[0] = 1;
  for (let j = 1; j < n; j++) {
    let v = j <= theta.length ? theta[j - 1] : 0;
    for (let i = 1; i <= phi.length; i++) if (j - i >= 0) v += phi[i - 1] * psi[j - i];
    psi[j] = v;
  }
  return psi;
}

/** Theoretical autocorrelations rho_1..rho_K of a stationary ARMA(p,q). */
export function theoreticalAcf(phi: number[], theta: number[], K = 24): number[] {
  const psi = psiWeights(phi, theta, 1500);
  const gamma = (k: number) => { let s = 0; for (let j = 0; j + k < psi.length; j++) s += psi[j] * psi[j + k]; return s; };
  const g0 = gamma(0);
  return Array.from({ length: K }, (_, i) => gamma(i + 1) / g0);
}

/** Partial autocorrelations from autocorrelations rho_1..rho_K (Durbin-Levinson recursion). */
export function pacfFromAcf(rho: number[]): number[] {
  const K = rho.length, out: number[] = [];
  let prev: number[] = [];
  for (let k = 1; k <= K; k++) {
    let num = rho[k - 1], den = 1;
    for (let j = 1; j < k; j++) { num -= prev[j - 1] * rho[k - j - 1]; den -= prev[j - 1] * rho[j - 1]; }
    const pkk = num / den;
    const cur = prev.map((v, j) => v - pkk * prev[k - j - 2]);
    cur.push(pkk);
    out.push(pkk);
    prev = cur;
  }
  return out;
}

/** Sample autocorrelations at lags 1..K (same estimator as R's acf()). */
export function sampleAcf(y: number[], K = 24): number[] {
  const n = y.length, m = y.reduce((a, b) => a + b, 0) / n;
  const d = y.map((v) => v - m);
  const c0 = d.reduce((a, v) => a + v * v, 0) / n;
  return Array.from({ length: K }, (_, i) => {
    const k = i + 1; let s = 0;
    for (let t = k; t < n; t++) s += d[t] * d[t - k];
    return s / n / c0;
  });
}

/** Simulate an ARMA(p,q) path of length n with N(0,1) shocks, after a burn-in. */
export function simulateArma(phi: number[], theta: number[], n: number, seed = 7, burn = 300): number[] {
  const r = rng(seed);
  const N = n + burn, e = Array.from({ length: N }, () => r.norm()), y = new Array(N).fill(0);
  for (let t = 0; t < N; t++) {
    let v = e[t];
    for (let i = 1; i <= phi.length; i++) if (t - i >= 0) v += phi[i - 1] * y[t - i];
    for (let j = 1; j <= theta.length; j++) if (t - j >= 0) v += theta[j - 1] * e[t - j];
    y[t] = v;
  }
  return y.slice(burn);
}

/** Is an AR polynomial stationary? Checked via the AR(2) triangle (enough for p <= 2). */
export function arStationary(phi: number[]): boolean {
  if (phi.length === 0) return true;
  if (phi.length === 1) return Math.abs(phi[0]) < 1;
  const [a, b] = phi;
  return b + a < 1 && b - a < 1 && Math.abs(b) < 1;
}

/** h-step forecast standard deviation of an AR(1) with unit shock variance. */
export function ar1FcSd(phi: number, h: number): number {
  let s = 0;
  for (let j = 0; j < h; j++) s += phi ** (2 * j);
  return Math.sqrt(s);
}
