// Chapter 6 — small, dependency-free exponential smoothing routines for the explorables.
// These are teaching versions: parameters are found by coarse grid search and initial states by a
// simple heuristic, whereas R's ets() optimizes everything (including initial states) by maximum likelihood.
// Numbers therefore differ a little from the code labs.

const sum = (a: number[]) => a.reduce((s, v) => s + v, 0);
const avg = (a: number[]) => sum(a) / a.length;

// ── Simple exponential smoothing ─────────────────────────────
/** SES with level started at y[0]. fitted[t] is the one-step forecast of y[t] made at t-1. */
export function sesRun(y: number[], alpha: number) {
  let l = y[0];
  const fitted: number[] = [];
  for (const v of y) { fitted.push(l); l = alpha * v + (1 - alpha) * l; }
  const err = y.map((v, i) => v - fitted[i]);
  const sse = sum(err.slice(1).map((e) => e * e));
  return { fitted, level: l, err, sse };
}
/** Alpha in [0.01, 1] minimizing one-step SSE (grid of 0.01). */
export function sesBestAlpha(y: number[]) {
  let best = 1, bestSse = Infinity;
  for (let k = 1; k <= 100; k++) { const a = k / 100; const s = sesRun(y, a).sse; if (s < bestSse) { bestSse = s; best = a; } }
  return best;
}
/** Weight SES puts on the observation j periods back: alpha (1 - alpha)^j. */
export const sesWeight = (alpha: number, j: number) => alpha * (1 - alpha) ** j;

// ── Holt's linear / damped trend ─────────────────────────────
export function holtRun(y: number[], alpha: number, beta: number, phi: number, h: number) {
  let l = y[0], b = y[1] - y[0];
  let sse = 0;
  for (let t = 1; t < y.length; t++) {
    const f = l + phi * b, e = y[t] - f;
    sse += e * e;
    const lp = l;
    l = f + alpha * e;
    b = phi * b + beta * (l - lp - phi * b) ; // beta* form: b = beta*(l - lp) + (1-beta)*phi*b
  }
  const forecast: number[] = [];
  let damp = 0;
  for (let i = 1; i <= h; i++) { damp += phi ** i; forecast.push(l + damp * b); }
  const limit = phi < 1 ? l + (phi / (1 - phi)) * b : Infinity;
  return { forecast, level: l, slope: b, sse, limit };
}
/** Holt with alpha chosen by grid (0.05 steps) for given beta and phi. */
export function holtFit(y: number[], beta: number, phi: number, h: number) {
  let best: ReturnType<typeof holtRun> | null = null, ba = 0.5;
  for (let k = 1; k <= 20; k++) {
    const a = k / 20; const r = holtRun(y, a, beta, phi, h);
    if (!best || r.sse < best.sse) { best = r; ba = a; }
  }
  return { ...best!, alpha: ba };
}

// ── Holt-Winters with seasonal history (additive or multiplicative) ──
function hwInit(y: number[], m: number, mult: boolean) {
  const a1 = avg(y.slice(0, m)), a2 = avg(y.slice(m, 2 * m));
  const s = y.slice(0, m).map((v) => (mult ? v / a1 : v - a1));
  return { l: a1, b: (a2 - a1) / m, s };
}
/** Runs Holt-Winters from t = m (first year used for initialization). Records the seasonal index applied each month. */
export function hwRun(y: number[], m: number, alpha: number, beta: number, gamma: number, mult: boolean, h = 0) {
  const ini = hwInit(y, m, mult);
  let { l, b } = ini; const s = ini.s.slice();
  const fitted: (number | null)[] = Array(m).fill(null);
  const applied: (number | null)[] = Array(m).fill(null);
  let sse = 0, sape = 0, n = 0;
  for (let t = m; t < y.length; t++) {
    const st = s[t % m];
    const f = mult ? (l + b) * st : l + b + st;
    fitted.push(f); applied.push(st);
    const e = y[t] - f; sse += e * e; sape += Math.abs(e / y[t]); n++;
    const lp = l;
    l = mult ? alpha * (y[t] / st) + (1 - alpha) * (lp + b) : alpha * (y[t] - st) + (1 - alpha) * (lp + b);
    b = beta * (l - lp) + (1 - beta) * b;
    s[t % m] = mult ? gamma * (y[t] / l) + (1 - gamma) * st : gamma * (y[t] - l) + (1 - gamma) * st;
  }
  const forecast = Array.from({ length: h }, (_, i) => { const st = s[(y.length + i) % m]; return mult ? (l + (i + 1) * b) * st : l + (i + 1) * b + st; });
  return { fitted, applied, forecast, sse, mape: (100 * sape) / n, level: l, slope: b, season: s };
}
/** Holt-Winters with alpha and beta chosen by grid for a given gamma. */
export function hwFit(y: number[], m: number, gamma: number, mult: boolean, h = 0) {
  let best: ReturnType<typeof hwRun> | null = null, pa = 0, pb = 0;
  for (let ai = 1; ai <= 19; ai++) for (const bb of [0, 0.01, 0.03, 0.1]) {
    const a = ai / 20; const r = hwRun(y, m, a, bb, gamma, mult, h);
    if (!best || r.sse < best.sse) { best = r; pa = a; pb = bb; }
  }
  return { ...best!, alpha: pa, beta: pb };
}

// ── ETS(M,Ad,M) in error-correction form, for the batch dashboard ──
export interface EtsPar { alpha: number; beta: number; gamma: number; phi: number }
interface State { l: number; b: number; s: number[] }
function etsInit(y: number[], m: number): State {
  const a1 = avg(y.slice(0, m)), a2 = avg(y.slice(m, 2 * m));
  return { l: a1, b: (a2 - a1) / m, s: y.slice(0, m).map((v) => v / a1) };
}
/** Filter y through ETS(M,Ad,M). Returns the concentrated -2 log-likelihood (as in R's ets()) and the final state. */
export function etsFilter(y: number[], m: number, p: EtsPar, init?: State) {
  const st0 = init ?? etsInit(y, m);
  let l = st0.l, b = st0.b; const s = st0.s.slice();
  let see = 0, slog = 0; const rel: number[] = [];
  const start = init ? 0 : m; // when initialized from the first year, start filtering after it
  for (let t = start; t < y.length; t++) {
    const k = t % m, mu = (l + p.phi * b) * s[k];
    if (!(mu > 0)) return { lik: Infinity, state: { l, b, s }, rel };
    const e = (y[t] - mu) / mu; rel.push(e);
    see += e * e; slog += Math.log(Math.abs(mu));
    const lb = l + p.phi * b;
    l = lb * (1 + p.alpha * e);
    b = p.phi * b + p.beta * lb * e;
    s[k] = s[k] * (1 + p.gamma * e);
  }
  const n = rel.length;
  return { lik: n * Math.log(see) + 2 * slog, state: { l, b, s }, rel, sigma: Math.sqrt(see / n), offset: y.length };
}
const GRID: EtsPar[] = [];
for (const alpha of [0.1, 0.2, 0.3, 0.45, 0.6, 0.8]) for (const beta of [0, 0.01, 0.05]) for (const gamma of [0.01, 0.1, 0.25, 0.45]) for (const phi of [0.9, 0.98, 1])
  if (beta <= alpha && gamma <= 1 - alpha) GRID.push({ alpha, beta, gamma, phi });

/** Choose ETS(M,Ad,M) parameters by grid search on the likelihood. */
export function etsFit(y: number[], m: number) {
  let best: EtsPar = GRID[0], bl = Infinity;
  for (const p of GRID) { const r = etsFilter(y, m, p); if (r.lik < bl) { bl = r.lik; best = p; } }
  return { par: best, ...etsFilter(y, m, best) };
}
/** Point forecasts plus simulated 80% interval from the final state. tIndex = index of first future period. */
export function etsForecast(state: State, m: number, p: EtsPar, sigma: number, h: number, tIndex: number, nsim = 300, seed = 7) {
  const mean: number[] = [];
  { let l = state.l, b = state.b; let damp = 0;
    for (let i = 1; i <= h; i++) { damp += p.phi ** i; mean.push((l + damp * b) * state.s[(tIndex + i - 1) % m]); } }
  // simulate future sample paths to get intervals (multiplicative errors make them asymmetric)
  let r = seed >>> 0;
  const u = () => { r = (r + 0x6d2b79f5) >>> 0; let t = r; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  const norm = () => Math.sqrt(-2 * Math.log(u() || 1e-12)) * Math.cos(2 * Math.PI * u());
  const paths: number[][] = Array.from({ length: h }, () => []);
  for (let k = 0; k < nsim; k++) {
    let l = state.l, b = state.b; const s = state.s.slice();
    for (let i = 0; i < h; i++) {
      const j = (tIndex + i) % m, lb = l + p.phi * b, mu = lb * s[j], e = sigma * norm();
      paths[i].push(mu * (1 + e));
      l = lb * (1 + p.alpha * e); b = p.phi * b + p.beta * lb * e; s[j] = s[j] * (1 + p.gamma * e);
    }
  }
  const q = (a: number[], pr: number) => { const z = a.slice().sort((x, y) => x - y); return z[Math.min(z.length - 1, Math.max(0, Math.round(pr * (z.length - 1))))]; };
  return { mean, lo: paths.map((a) => q(a, 0.1)), hi: paths.map((a) => q(a, 0.9)) };
}

/** MASE: test MAE divided by the in-sample MAE of seasonal naive. */
export function mase(actual: number[], fc: number[], train: number[], m: number) {
  const mae = avg(actual.map((a, i) => Math.abs(a - fc[i])));
  const sc = avg(train.slice(m).map((v, i) => Math.abs(v - train[i])));
  return mae / sc;
}
export const mape = (actual: number[], fc: number[]) => (100 * avg(actual.map((a, i) => Math.abs((a - fc[i]) / a))));
