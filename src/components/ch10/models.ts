// Chapter 11 toolkit: a small additive exponential-smoothing model (fitted on logs) that can
// forecast, simulate future sample paths, and produce one-step out-of-sample errors.
// Pure functions, no DOM, so the numbers quoted in the chapter can be reproduced with `npx tsx`.

export interface Spec { m: number; trend: boolean; season: boolean }
export interface Params { alpha: number; beta: number; gamma: number }
export interface State { l: number; b: number; s: number[]; t: number } // s[j] = seasonal for period (t + j) mod m … stored by absolute index mod m
export interface Fit { spec: Spec; par: Params; fitted: number[]; resid: number[]; sigma: number; state: State }

const mean = (a: number[]) => a.reduce((x, y) => x + y, 0) / a.length;

/** Run the error-correction recursions with fixed parameters over y (already on the log scale).
 *  fitted[t] is the one-step forecast of y[t] made with data up to t-1 only. */
export function filter(y: number[], spec: Spec, par: Params) {
  const { m, trend, season } = spec;
  const k = season ? m : 1;
  let l = season ? mean(y.slice(0, m)) : y[0];
  let b = trend ? (season ? (mean(y.slice(m, 2 * m)) - mean(y.slice(0, m))) / m : y[1] - y[0]) : 0;
  const s: number[] = season ? y.slice(0, m).map((v) => v - l) : [0];
  // shift the level back so that the first forecast is aligned with t = 0
  if (trend && season) l -= b * ((m - 1) / 2 + 1); else if (trend) l -= b;
  const fitted: number[] = [], resid: number[] = [];
  for (let t = 0; t < y.length; t++) {
    const st = season ? s[t % m] : 0;
    const f = l + b + st;
    const e = y[t] - f;
    fitted.push(f); resid.push(e);
    const lNew = l + b + par.alpha * e;
    b = trend ? b + par.alpha * par.beta * e : 0;
    if (season) s[t % m] = st + par.gamma * (1 - par.alpha) * e;
    l = lNew;
  }
  void k;
  return { fitted, resid, state: { l, b, s: s.slice(), t: y.length } as State };
}

const GRID_A = [0.05, 0.1, 0.15, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9];
const GRID_B = [0.01, 0.05, 0.1, 0.2];
const GRID_G = [0.01, 0.05, 0.1, 0.2, 0.3, 0.5];

/** Fit by grid search on one-step squared error (burn-in of one season is ignored). */
export function fitETS(y: number[], spec: Spec): Fit {
  const burn = spec.season ? spec.m : 2;
  let best: { sse: number; par: Params } = { sse: Infinity, par: { alpha: 0.3, beta: 0.05, gamma: 0.1 } };
  for (const alpha of GRID_A) for (const beta of spec.trend ? GRID_B : [0]) for (const gamma of spec.season ? GRID_G : [0]) {
    const par = { alpha, beta, gamma };
    const { resid } = filter(y, spec, par);
    let sse = 0; for (let t = burn; t < resid.length; t++) sse += resid[t] * resid[t];
    if (sse < best.sse) best = { sse, par };
  }
  const r = filter(y, spec, best.par);
  const used = r.resid.slice(burn);
  const sigma = Math.sqrt(used.reduce((a, e) => a + e * e, 0) / Math.max(1, used.length - 1));
  return { spec, par: best.par, fitted: r.fitted, resid: used, sigma, state: r.state };
}

/** Point forecast (log scale) h steps from the end of the fitted data. */
export function forecast(fit: Fit, h: number): number[] {
  const { l, b, s, t } = fit.state, { m, season } = fit.spec;
  return Array.from({ length: h }, (_, i) => l + (i + 1) * b + (season ? s[(t + i) % m] : 0));
}

/** Analytic h-step standard deviation for this additive model (log scale). */
export function sdH(fit: Fit, h: number): number[] {
  const { alpha, beta, gamma } = fit.par, { m, trend, season } = fit.spec;
  const out: number[] = []; let acc = 0;
  for (let j = 1; j <= h; j++) {
    out.push(fit.sigma * Math.sqrt(1 + acc));
    // c_j coefficient for the next step
    const cj = alpha * (1 + (trend ? j * beta : 0)) + (season && j % m === 0 ? gamma * (1 - alpha) : 0);
    acc += cj * cj;
  }
  return out;
}

/** One simulated future path (log scale) by bootstrapping past residuals (or normal draws if pool is empty). */
export function simulate(fit: Fit, h: number, u: () => number, pool: number[], norm?: () => number): number[] {
  let { l, b } = fit.state; const s = fit.state.s.slice(); const t0 = fit.state.t;
  const { m, trend, season } = fit.spec, { alpha, beta, gamma } = fit.par;
  const out: number[] = [];
  for (let i = 0; i < h; i++) {
    const idx = (t0 + i) % m;
    const st = season ? s[idx] : 0;
    const e = pool.length ? pool[Math.floor(u() * pool.length)] : fit.sigma * (norm ? norm() : 0);
    const y = l + b + st + e;
    out.push(y);
    const lNew = l + b + alpha * e;
    b = trend ? b + alpha * beta * e : 0;
    if (season) s[idx] = st + gamma * (1 - alpha) * e;
    l = lNew;
  }
  return out;
}

/** Sample quantile with linear interpolation (R type 7). */
export function quantile(xs: number[], p: number): number {
  const a = xs.slice().sort((x, y) => x - y);
  const h = (a.length - 1) * p, lo = Math.floor(h), hi = Math.ceil(h);
  return a[lo] + (h - lo) * (a[hi] - a[lo]);
}
/** Split-conformal quantile: the ceil((n+1)(1-alpha))-th smallest score (Infinity if n is too small). */
export function conformalQ(scores: number[], alpha: number): number {
  const a = scores.slice().sort((x, y) => x - y), n = a.length;
  const k = Math.ceil((n + 1) * (1 - alpha));
  return k > n ? Infinity : a[k - 1];
}
/** Standard normal quantile (Acklam's rational approximation, |error| < 1.2e-9). */
export function qnorm(p: number): number {
  const a = [-3.969683028665376e1, 2.209460984245205e2, -2.759285104469687e2, 1.38357751867269e2, -3.066479806614716e1, 2.506628277459239];
  const b = [-5.447609879822406e1, 1.615858368580409e2, -1.556989798598866e2, 6.680131188771972e1, -1.328068155288572e1];
  const c = [-7.784894002430293e-3, -3.223964580411365e-1, -2.400758277161838, -2.549671010229537, 4.374664141464968, 2.938163982698783];
  const d = [7.784695709041462e-3, 3.224671290700398e-1, 2.445134137142996, 3.754408661907416];
  const pl = 0.02425;
  if (p < pl) { const q = Math.sqrt(-2 * Math.log(p)); return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1); }
  if (p > 1 - pl) return -qnorm(1 - p);
  const q = p - 0.5, r = q * q;
  return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q / (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
}
/** Pinball (quantile) loss of a quantile forecast q for level tau when y happens. */
export const pinball = (y: number, q: number, tau: number) => (y >= q ? tau * (y - q) : (1 - tau) * (q - y));

/** Expected newsvendor cost of stocking Q given demand draws D, understock cost cu and overstock cost co (per unit). */
export function expectedCost(D: number[], Q: number, cu: number, co: number) {
  let s = 0; for (const d of D) s += d > Q ? cu * (d - Q) : co * (Q - d);
  return s / D.length;
}
