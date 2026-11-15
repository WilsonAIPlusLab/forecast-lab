// Forecast Studio engine: model fitting, rolling-origin evaluation, empirical intervals, executive summary.
// Pure functions (no DOM), so the same code can be run in Node to verify the numbers quoted in the chapter.
import { fcNaive, fcSNaive, fcDrift, ses, holt, holtWinters, mean } from '../../lib/ts';

export type ModelKey = 'naive' | 'snaive' | 'drift' | 'ses' | 'holt' | 'hwa' | 'hwm' | 'combo';
export interface ModelInfo { k: ModelKey; label: string; short: string; kind: 'benchmark' | 'smoothing' | 'combo'; desc: string }

export const MODELS: ModelInfo[] = [
  { k: 'naive', label: 'Naive', short: 'Naive', kind: 'benchmark', desc: 'last value carried forward' },
  { k: 'snaive', label: 'Seasonal naive', short: 'S. naive', kind: 'benchmark', desc: 'same month last year' },
  { k: 'drift', label: 'Drift', short: 'Drift', kind: 'benchmark', desc: 'straight line through the first and last points' },
  { k: 'ses', label: 'Simple exp. smoothing', short: 'SES', kind: 'smoothing', desc: 'weighted average of the past, flat forecast' },
  { k: 'holt', label: 'Holt (damped trend)', short: 'Holt damped', kind: 'smoothing', desc: 'level + a trend that flattens out' },
  { k: 'hwa', label: 'Holt-Winters additive', short: 'HW add.', kind: 'smoothing', desc: 'level + trend + fixed-size seasonal swings' },
  { k: 'hwm', label: 'Holt-Winters multiplicative', short: 'HW mult.', kind: 'smoothing', desc: 'level + trend + seasonal swings that scale with the level' },
  { k: 'combo', label: 'Combination', short: 'Combo', kind: 'combo', desc: 'equal-weight average of the selected smoothing models' },
];
export const modelInfo = (k: ModelKey) => MODELS.find((m) => m.k === k)!;

// ── parameter estimation: Nelder–Mead on an unconstrained scale ──
const sig = (z: number) => 1 / (1 + Math.exp(-z));
const logit = (p: number) => Math.log(p / (1 - p));

function nelderMead(f: (z: number[]) => number, x0: number[], maxIter = 160, tol = 1e-7): number[] {
  const n = x0.length;
  let pts = [x0.slice(), ...x0.map((_, i) => x0.map((v, j) => (i === j ? v + 0.6 : v)))];
  let vals = pts.map(f);
  for (let it = 0; it < maxIter; it++) {
    const ord = vals.map((v, i) => i).sort((a, b) => vals[a] - vals[b]);
    pts = ord.map((i) => pts[i]); vals = ord.map((i) => vals[i]);
    if (Math.abs(vals[n] - vals[0]) <= tol * (Math.abs(vals[0]) + 1e-12)) break;
    const c = Array.from({ length: n }, (_, j) => mean(pts.slice(0, n).map((p) => p[j])));
    const at = (t: number) => c.map((cj, j) => cj + t * (pts[n][j] - cj));
    const xr = at(-1), fr = f(xr);
    if (fr < vals[0]) { const xe = at(-2), fe = f(xe); if (fe < fr) { pts[n] = xe; vals[n] = fe; } else { pts[n] = xr; vals[n] = fr; } }
    else if (fr < vals[n - 1]) { pts[n] = xr; vals[n] = fr; }
    else {
      const xc = fr < vals[n] ? at(-0.5) : at(0.5), fc = f(xc);
      if (fc < Math.min(fr, vals[n])) { pts[n] = xc; vals[n] = fc; }
      else { for (let i = 1; i <= n; i++) { pts[i] = pts[i].map((v, j) => pts[0][j] + 0.5 * (v - pts[0][j])); vals[i] = f(pts[i]); } }
    }
  }
  return pts[vals.indexOf(Math.min(...vals))];
}

const sse = (y: number[], fitted: number[], skip: number) => { let s = 0; for (let t = skip; t < y.length; t++) { const e = y[t] - fitted[t]; s += e * e; } return Number.isFinite(s) ? s : 1e300; };

// Map unconstrained z to admissible parameters (beta <= alpha, gamma <= 1 - alpha, damping 0.8–0.98, as in R's ets()).
const pSES = (z: number[]) => ({ alpha: 0.0001 + 0.9998 * sig(z[0]) });
const pHolt = (z: number[]) => { const alpha = 0.0001 + 0.9998 * sig(z[0]); return { alpha, beta: alpha * sig(z[1]), phi: 0.8 + 0.18 * sig(z[2]) }; };
const pHW = (z: number[]) => { const alpha = 0.0001 + 0.9998 * sig(z[0]); return { alpha, beta: alpha * sig(z[1]), gamma: (1 - alpha) * sig(z[2]) }; };
const Z0: Record<string, number[]> = { ses: [logit(0.5)], holt: [logit(0.5), logit(0.1), 0.5], hwa: [logit(0.3), logit(0.1), logit(0.1)], hwm: [logit(0.3), logit(0.1), logit(0.1)] };

export interface Fit { fc: number[]; z?: number[]; params?: Record<string, number> }

/** Fit one model to y and forecast h steps. warm = starting point for the optimizer (speeds up rolling origins). */
export function fitForecast(k: Exclude<ModelKey, 'combo'>, y: number[], h: number, m: number, warm?: number[]): Fit {
  switch (k) {
    case 'naive': return { fc: fcNaive(y, h) };
    case 'snaive': return { fc: fcSNaive(y, h, m) };
    case 'drift': return { fc: fcDrift(y, h) };
    case 'ses': {
      const z = nelderMead((z) => sse(y, ses(y, pSES(z).alpha).fitted, 1), warm ?? Z0.ses, 80);
      const p = pSES(z); return { fc: ses(y, p.alpha, h).forecast, z, params: p };
    }
    case 'holt': {
      const z = nelderMead((z) => { const p = pHolt(z); return sse(y, holt(y, p.alpha, p.beta, 0, p.phi).fitted, 2); }, warm ?? Z0.holt);
      const p = pHolt(z); return { fc: holt(y, p.alpha, p.beta, h, p.phi).forecast, z, params: p };
    }
    case 'hwa': case 'hwm': {
      const mult = k === 'hwm';
      const z = nelderMead((z) => { const p = pHW(z); return sse(y, holtWinters(y, m, p.alpha, p.beta, p.gamma, 0, mult).fitted, m); }, warm ?? Z0[k]);
      const p = pHW(z); return { fc: holtWinters(y, m, p.alpha, p.beta, p.gamma, h, mult).forecast, z, params: p };
    }
  }
}

/** R's default (type 7) sample quantile. */
export function quantile(xs: number[], p: number) {
  const s = xs.filter(Number.isFinite).sort((a, b) => a - b); if (!s.length) return NaN;
  const i = (s.length - 1) * p, lo = Math.floor(i), hi = Math.ceil(i);
  return s[lo] + (s[hi] - s[lo]) * (i - lo);
}

export interface Score { k: ModelKey; maeH: number[]; rmseH: number[]; meH: number[]; nH: number[]; MAE: number; RMSE: number; ME: number; MASE: number }
export interface StudioResult {
  y: number[]; H: number; m: number; K: number; origins: number[]; scale: number;
  models: ModelKey[]; errors: Record<string, number[][]>; scores: Score[]; best: ModelKey; ref: Score;
  forecasts: Record<string, number[]>; params: Record<string, Record<string, number> | undefined>;
}

/**
 * Rolling-origin evaluation inside the training data, then a final fit on all of it.
 * y: training data (ends at the "data through" date). K origins: the last K months of the training data.
 * At origin o the model sees y[0..o-1] and forecasts y[o..o+H-1]; errors are kept only where the actual is in y.
 */
export function runStudio(y: number[], H: number, selected: ModelKey[], m = 12, K = 48): StudioResult {
  const T = y.length;
  const base = selected.filter((k) => k !== 'combo') as Exclude<ModelKey, 'combo'>[];
  const evalKeys = Array.from(new Set<Exclude<ModelKey, 'combo'>>([...base, 'snaive'])); // seasonal naive is always scored as the reference
  const smooth = base.filter((k) => modelInfo(k).kind === 'smoothing');
  const comboParts = smooth.length ? smooth : base;
  const wantCombo = selected.includes('combo') && comboParts.length > 0;
  const firstO = Math.max(2 * m + 6, T - K);
  const origins: number[] = []; for (let o = firstO; o < T; o++) origins.push(o);
  const errors: Record<string, number[][]> = {};
  const all = [...evalKeys, ...(wantCombo ? ['combo'] : [])];
  for (const k of all) errors[k] = Array.from({ length: H }, () => []);
  const warm: Record<string, number[] | undefined> = {};
  for (const o of origins) {
    const tr = y.slice(0, o), fcs: Record<string, number[]> = {};
    for (const k of evalKeys) { const f = fitForecast(k, tr, H, m, warm[k]); warm[k] = f.z; fcs[k] = f.fc; }
    if (wantCombo) fcs.combo = Array.from({ length: H }, (_, i) => mean(comboParts.map((k) => fcs[k][i])));
    for (let i = 0; i < H && o + i < T; i++) for (const k of all) errors[k][i].push(y[o + i] - fcs[k][i]);
  }
  const scale = mean(y.slice(m).map((v, i) => Math.abs(v - y[i]))); // in-sample seasonal naive MAE, as in R's accuracy()
  const score = (k: ModelKey): Score => {
    const E = errors[k];
    const maeH = E.map((e) => mean(e.map(Math.abs))), rmseH = E.map((e) => Math.sqrt(mean(e.map((x) => x * x)))), meH = E.map((e) => mean(e));
    const MAE = mean(maeH);
    return { k, maeH, rmseH, meH, nH: E.map((e) => e.length), MAE, RMSE: mean(rmseH), ME: mean(meH), MASE: MAE / scale };
  };
  const shown = selected.filter((k) => errors[k]);
  const scores = shown.map(score);
  const ref = score('snaive');
  const best = scores.length ? scores.slice().sort((a, b) => a.MAE - b.MAE)[0].k : 'snaive';
  // Final fit on all the training data.
  const forecasts: Record<string, number[]> = {}, params: StudioResult['params'] = {};
  for (const k of evalKeys) { const f = fitForecast(k, y, H, m, warm[k]); forecasts[k] = f.fc; params[k] = f.params; }
  if (wantCombo) forecasts.combo = Array.from({ length: H }, (_, i) => mean(comboParts.map((k) => forecasts[k][i])));
  return { y, H, m, K: origins.length, origins, scale, models: shown, errors, scores, best, ref, forecasts, params };
}

/** Empirical prediction interval at each horizon: point forecast + quantiles of past errors at that horizon. */
export function empiricalBands(res: StudioResult, k: ModelKey, levels = [50, 80]) {
  const fc = res.forecasts[k];
  return levels.map((L) => {
    const a = (1 - L / 100) / 2;
    return { level: L, lo: fc.map((f, i) => f + quantile(res.errors[k][i], a)), hi: fc.map((f, i) => f + quantile(res.errors[k][i], 1 - a)) };
  });
}
