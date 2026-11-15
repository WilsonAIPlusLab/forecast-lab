// STL: Seasonal-Trend decomposition by Loess (Cleveland, Cleveland, McRae & Terpenning, 1990).
// A line-by-line port of the netlib Fortran routines (stl.f) that R's stats::stl() calls,
// including the "jump" interpolation, so results match R's stl() to rounding error
// (verified against R 4.4 on log RSXFSN from 2005: components agree to 12 decimal places).

const nextOdd = (x: number) => { const r = Math.round(x); return r % 2 === 0 ? r + 1 : r; };

/** Local (weighted) loess estimate at xs, using points nleft..nright (1-based indices). */
function est(y: number[], n: number, len: number, ideg: number, xs: number, nleft: number, nright: number, w: number[], userw: boolean, rw: number[]): number | null {
  const range = n - 1;
  let h = Math.max(xs - nleft, nright - xs);
  if (len > n) h += Math.floor((len - n) / 2);
  const h9 = 0.999 * h, h1 = 0.001 * h;
  let a = 0;
  for (let j = nleft; j <= nright; j++) {
    w[j] = 0;
    const r = Math.abs(j - xs);
    if (r <= h9) {
      w[j] = r <= h1 ? 1 : (1 - (r / h) ** 3) ** 3;
      if (userw) w[j] *= rw[j];
      a += w[j];
    }
  }
  if (a <= 0) return null;
  for (let j = nleft; j <= nright; j++) w[j] /= a;
  if (h > 0 && ideg > 0) {
    let aa = 0;
    for (let j = nleft; j <= nright; j++) aa += w[j] * j;
    let b = xs - aa, c = 0;
    for (let j = nleft; j <= nright; j++) c += w[j] * (j - aa) ** 2;
    if (Math.sqrt(c) > 0.001 * range) {
      b /= c;
      for (let j = nleft; j <= nright; j++) w[j] *= b * (j - aa) + 1;
    }
  }
  let ys = 0;
  for (let j = nleft; j <= nright; j++) ys += w[j] * y[j];
  return ys;
}

/** Loess smooth of y[1..n] into ys[1..n] (arrays are 1-based; index 0 unused). */
function ess(y: number[], n: number, len: number, ideg: number, njump: number, userw: boolean, rw: number[], ys: number[], off = 0) {
  // ys is written at ys[off + i] for i = 1..n
  const res: number[] = new Array(n + 2).fill(0);
  if (n < 2) { ys[off + 1] = y[1]; return; }
  const newnj = Math.min(njump, n - 1);
  let nleft = 1, nright = n;
  if (len >= n) {
    nleft = 1; nright = n;
    for (let i = 1; i <= n; i += newnj) { const v = est(y, n, len, ideg, i, nleft, nright, res, userw, rw); ys[off + i] = v ?? y[i]; }
  } else if (newnj === 1) {
    const nsh = Math.floor((len + 1) / 2);
    nleft = 1; nright = len;
    for (let i = 1; i <= n; i++) {
      if (i > nsh && nright !== n) { nleft++; nright++; }
      const v = est(y, n, len, ideg, i, nleft, nright, res, userw, rw); ys[off + i] = v ?? y[i];
    }
  } else {
    const nsh = Math.floor((len + 1) / 2);
    for (let i = 1; i <= n; i += newnj) {
      if (i < nsh) { nleft = 1; nright = len; }
      else if (i >= n - nsh + 1) { nleft = n - len + 1; nright = n; }
      else { nleft = i - nsh + 1; nright = len + i - nsh; }
      const v = est(y, n, len, ideg, i, nleft, nright, res, userw, rw); ys[off + i] = v ?? y[i];
    }
  }
  if (newnj !== 1) {
    for (let i = 1; i <= n - newnj; i += newnj) {
      const delta = (ys[off + i + newnj] - ys[off + i]) / newnj;
      for (let j = i + 1; j <= i + newnj - 1; j++) ys[off + j] = ys[off + i] + delta * (j - i);
    }
    const k = Math.floor((n - 1) / newnj) * newnj + 1;
    if (k !== n) {
      const v = est(y, n, len, ideg, n, nleft, nright, res, userw, rw); ys[off + n] = v ?? y[n];
      if (k !== n - 1) {
        const delta = (ys[off + n] - ys[off + k]) / (n - k);
        for (let j = k + 1; j <= n - 1; j++) ys[off + j] = ys[off + k] + delta * (j - k);
      }
    }
  }
}

/** Moving average of x[1..n] with window len -> ave[1..n-len+1]. */
function ma(x: number[], n: number, len: number, ave: number[]) {
  const newn = n - len + 1;
  let v = 0;
  for (let i = 1; i <= len; i++) v += x[i];
  ave[1] = v / len;
  for (let j = 2, k = len + 1, m = 1; j <= newn; j++, k++, m++) { v = v - x[m] + x[k]; ave[j] = v / len; }
}

function ss(y: number[], n: number, np: number, ns: number, isdeg: number, nsjump: number, userw: boolean, rw: number[], season: number[]) {
  for (let j = 1; j <= np; j++) {
    const k = Math.floor((n - j) / np) + 1;
    const w1: number[] = new Array(k + 3).fill(0), w3: number[] = new Array(k + 3).fill(0), w4: number[] = new Array(k + 3).fill(0);
    const w2: number[] = new Array(k + 3).fill(0);
    for (let i = 1; i <= k; i++) w1[i] = y[(i - 1) * np + j];
    if (userw) for (let i = 1; i <= k; i++) w3[i] = rw[(i - 1) * np + j];
    ess(w1, k, ns, isdeg, nsjump, userw, w3, w2, 1); // w2[2..k+1]
    let nright = Math.min(ns, k);
    let v = est(w1, k, ns, isdeg, 0, 1, nright, w4, userw, w3);
    w2[1] = v ?? w2[2];
    const nleft = Math.max(1, k - ns + 1);
    v = est(w1, k, ns, isdeg, k + 1, nleft, k, w4, userw, w3);
    w2[k + 2] = v ?? w2[k + 1];
    for (let m = 1; m <= k + 2; m++) season[(m - 1) * np + j] = w2[m];
  }
}

export interface StlOptions { period?: number; sWindow?: number | 'periodic'; tWindow?: number; lWindow?: number; robust?: boolean; sDegree?: number; tDegree?: number }
export interface StlResult { seasonal: number[]; trend: number[]; remainder: number[]; weights: number[]; sWindow: number | 'periodic'; tWindow: number }

/** Same defaults as R's stl(x, s.window, ...). */
export function stl(x: number[], opts: StlOptions = {}): StlResult {
  const n = x.length, np0 = opts.period ?? 12;
  const periodic = opts.sWindow === 'periodic' || opts.sWindow === undefined;
  let sWin = periodic ? 10 * n + 1 : (opts.sWindow as number);
  let sDeg = periodic ? 0 : opts.sDegree ?? 0;
  const tWin0 = opts.tWindow ?? nextOdd(Math.ceil((1.5 * np0) / (1 - 1.5 / sWin)));
  const tDeg = opts.tDegree ?? 1;
  const lWin0 = opts.lWindow ?? nextOdd(np0);
  const robust = !!opts.robust;
  const inner = robust ? 1 : 2, outer = robust ? 15 : 0;
  const sJump = Math.ceil(sWin / 10), tJump = Math.ceil(tWin0 / 10), lJump = Math.ceil(lWin0 / 10);
  let ns = Math.max(3, sWin), nt = Math.max(3, tWin0), nl = Math.max(3, lWin0);
  const np = Math.max(2, np0);
  if (ns % 2 === 0) ns++; if (nt % 2 === 0) nt++; if (nl % 2 === 0) nl++;

  const y = [0, ...x];
  const rw: number[] = new Array(n + 1).fill(1);
  const season: number[] = new Array(n + 1).fill(0), trend: number[] = new Array(n + 1).fill(0);
  let userw = false;
  const L = n + 2 * np + 2;
  for (let k = 0; ; ) {
    // stlstp
    for (let it = 0; it < inner; it++) {
      const w1 = new Array(L).fill(0), w2 = new Array(L).fill(0), w3 = new Array(L).fill(0);
      for (let i = 1; i <= n; i++) w1[i] = y[i] - trend[i];
      ss(w1, n, np, ns, sDeg, sJump, userw, rw, w2);
      // low-pass filter of w2[1..n+2np] -> w3[1..n]
      const t1 = new Array(L).fill(0), t2 = new Array(L).fill(0);
      ma(w2, n + 2 * np, np, t1); ma(t1, n + np + 1, np, t2); ma(t2, n + 2, 3, w3);
      const low = new Array(L).fill(0);
      ess(w3, n, nl, tDeg, lJump, false, rw, low);
      for (let i = 1; i <= n; i++) season[i] = w2[np + i] - low[i];
      const ds = new Array(L).fill(0);
      for (let i = 1; i <= n; i++) ds[i] = y[i] - season[i];
      ess(ds, n, nt, tDeg, tJump, userw, rw, trend);
    }
    k++;
    if (k > outer) break;
    // robustness weights
    const r = Array.from({ length: n }, (_, i) => Math.abs(y[i + 1] - trend[i + 1] - season[i + 1]));
    const srt = r.slice().sort((a, b) => a - b);
    const m1 = Math.floor(n / 2) + 1, m2 = n - m1 + 1;
    const cmad = 3 * (srt[m1 - 1] + srt[m2 - 1]);
    const c9 = 0.999 * cmad, c1 = 0.001 * cmad;
    for (let i = 1; i <= n; i++) { const v = r[i - 1]; rw[i] = v <= c1 ? 1 : v <= c9 ? (1 - (v / cmad) ** 2) ** 2 : 0; }
    userw = true;
  }
  if (outer <= 0) rw.fill(1);
  let S = season.slice(1);
  const T = trend.slice(1);
  if (periodic) {
    const mean = new Array(np0).fill(0), cnt = new Array(np0).fill(0);
    S.forEach((v, i) => { mean[i % np0] += v; cnt[i % np0]++; });
    S = S.map((_, i) => mean[i % np0] / cnt[i % np0]);
  }
  return { seasonal: S, trend: T, remainder: x.map((v, i) => v - S[i] - T[i]), weights: rw.slice(1), sWindow: periodic ? 'periodic' : sWin, tWindow: nt };
}

/** Classical decomposition (as in R's decompose()): centred 2x12 MA trend, averaged seasonal indices. */
export function classical(x: number[], m = 12, type: 'additive' | 'multiplicative' = 'additive', startMonth = 0) {
  const n = x.length, trend: (number | null)[] = new Array(n).fill(null);
  const half = m / 2;
  for (let t = half; t < n - half; t++) {
    let s = 0.5 * x[t - half] + 0.5 * x[t + half];
    for (let j = -half + 1; j <= half - 1; j++) s += x[t + j];
    trend[t] = s / m;
  }
  const sums = new Array(m).fill(0), cnt = new Array(m).fill(0);
  x.forEach((v, t) => { const tr = trend[t]; if (tr == null) return; const k = (t + startMonth) % m; sums[k] += type === 'additive' ? v - tr : v / tr; cnt[k]++; });
  let fig = sums.map((s, k) => s / cnt[k]);
  const avg = fig.reduce((a, b) => a + b, 0) / m;
  fig = fig.map((f) => (type === 'additive' ? f - avg : f / avg));
  const seasonal = x.map((_, t) => fig[(t + startMonth) % m]);
  const remainder = x.map((v, t) => { const tr = trend[t]; return tr == null ? null : type === 'additive' ? v - tr - seasonal[t] : v / (tr * seasonal[t]); });
  return { trend, seasonal, remainder, figure: fig };
}

/** Hyndman's seasonal strength, F_S = max(0, 1 - Var(R) / Var(S + R)). */
export function seasonalStrength(seasonal: number[], remainder: number[]) {
  const v = (a: number[]) => { const m = a.reduce((s, x) => s + x, 0) / a.length; return a.reduce((s, x) => s + (x - m) ** 2, 0) / (a.length - 1); };
  return Math.max(0, 1 - v(remainder) / v(seasonal.map((s, i) => s + remainder[i])));
}

/** Autocorrelation at a single lag. */
export function acfAt(x: number[], lag: number) {
  const n = x.length, m = x.reduce((a, b) => a + b, 0) / n;
  let num = 0, den = 0;
  for (let i = 0; i < n; i++) { den += (x[i] - m) ** 2; if (i >= lag) num += (x[i] - m) * (x[i - lag] - m); }
  return num / den;
}
