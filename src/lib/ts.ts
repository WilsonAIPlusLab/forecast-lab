// Lightweight time-series toolkit in JS — powers instant explorables (no R/Python wait).
import { BASE } from './runtime/status';

export interface Pt { date: Date; value: number }
export interface Series { id: string; freq: number; data: Pt[] }

const cache = new Map<string, Promise<Series>>();

/** Load a bundled FRED CSV. opts.to aggregates daily/weekly data to monthly means. */
export function loadSeries(id: string, opts: { start?: string; end?: string; to?: 'month' | 'quarter' } = {}): Promise<Series> {
  const key = JSON.stringify([id, opts]);
  if (!cache.has(key)) {
    cache.set(key, (async () => {
      const txt = await (await fetch(`${BASE}data/${id}.csv`)).text();
      let data: Pt[] = txt.trim().split('\n').slice(1).map((l) => { const [d, v] = l.split(','); return { date: new Date(d + 'T00:00:00'), value: parseFloat(v) }; }).filter((p) => Number.isFinite(p.value));
      if (opts.to) {
        const m = new Map<string, number[]>();
        for (const p of data) {
          const mo = opts.to === 'month' ? p.date.getMonth() : Math.floor(p.date.getMonth() / 3) * 3;
          const k = `${p.date.getFullYear()}-${String(mo + 1).padStart(2, '0')}-01`;
          (m.get(k) || m.set(k, []).get(k)!).push(p.value);
        }
        data = [...m].map(([k, v]) => ({ date: new Date(k + 'T00:00:00'), value: v.reduce((a, b) => a + b, 0) / v.length }));
      }
      data = fillCalendarGaps(data);
      if (opts.start) data = data.filter((p) => p.date >= new Date(opts.start + 'T00:00:00'));
      if (opts.end) data = data.filter((p) => p.date <= new Date(opts.end + 'T00:00:00'));
      const gap = data.length > 2 ? (+data[2].date - +data[1].date) / 864e5 : 30;
      const freq = gap > 300 ? 1 : gap > 80 ? 4 : gap > 25 ? 12 : gap > 5 ? 52 : 365;
      return { id, freq, data };
    })());
  }
  return cache.get(key)!;
}

/** Monthly/quarterly data: put missing periods back on the calendar and linearly interpolate
 *  gaps of 1-2 periods (e.g. the Oct-2025 shutdown); drop older stretches with longer gaps. */
function fillCalendarGaps(data: Pt[]): Pt[] {
  if (data.length < 3) return data;
  const gaps = data.slice(1).map((p, i) => (+p.date - +data[i].date) / 864e5).sort((a, b) => a - b);
  const g = gaps[Math.floor(gaps.length / 2)];
  const step = g > 300 ? 12 : g > 80 ? 3 : g > 25 ? 1 : 0;
  if (!step) return data;
  // count all missing periods; if more than 3, keep only the data after the last gap (don't invent data)
  const monthsBetween = (a: Date, b: Date) => (b.getFullYear() - a.getFullYear()) * 12 + b.getMonth() - a.getMonth();
  let totalMissing = 0, lastGapEnd = 0;
  for (let i = 0; i + 1 < data.length; i++) { const miss = monthsBetween(data[i].date, data[i + 1].date) / step - 1; if (miss > 0) { totalMissing += miss; lastGapEnd = i + 1; } }
  if (totalMissing > 3) data = data.slice(lastGapEnd);
  const out: Pt[] = [];
  for (let i = 0; i < data.length; i++) {
    out.push(data[i]);
    const nxt = data[i + 1]; if (!nxt) break;
    const months = (nxt.date.getFullYear() - data[i].date.getFullYear()) * 12 + nxt.date.getMonth() - data[i].date.getMonth();
    const missing = months / step - 1;
    if (missing > 2) { out.length = 0; continue; } // long gap: restart after it
    for (let k = 1; k <= missing; k++) {
      const d = new Date(data[i].date); d.setMonth(d.getMonth() + k * step);
      out.push({ date: d, value: data[i].value + ((nxt.value - data[i].value) * k) / (missing + 1) });
    }
  }
  return out;
}

/** Add k periods to a date given frequency. */
export function addPeriods(d: Date, k: number, freq: number): Date {
  const n = new Date(d);
  if (freq === 12) n.setMonth(n.getMonth() + k);
  else if (freq === 4) n.setMonth(n.getMonth() + 3 * k);
  else if (freq === 1) n.setFullYear(n.getFullYear() + k);
  else n.setDate(n.getDate() + Math.round((365.25 / freq) * k));
  return n;
}
export const futureDates = (last: Date, h: number, freq: number) => Array.from({ length: h }, (_, i) => addPeriods(last, i + 1, freq));

// ── benchmark methods ──
export const mean = (y: number[]) => y.reduce((a, b) => a + b, 0) / y.length;
export function fcMean(y: number[], h: number) { const m = mean(y); return Array(h).fill(m); }
export function fcNaive(y: number[], h: number) { return Array(h).fill(y[y.length - 1]); }
export function fcSNaive(y: number[], h: number, m: number) { return Array.from({ length: h }, (_, i) => y[y.length - m + (i % m)]); }
export function fcDrift(y: number[], h: number) { const n = y.length, b = (y[n - 1] - y[0]) / (n - 1); return Array.from({ length: h }, (_, i) => y[n - 1] + b * (i + 1)); }

/** Simple exponential smoothing: returns fitted (one-step) values and flat forecast. */
export function ses(y: number[], alpha: number, h = 0) {
  let l = y[0]; const fitted: number[] = [];
  for (const v of y) { fitted.push(l); l = alpha * v + (1 - alpha) * l; }
  return { fitted, level: l, forecast: Array(h).fill(l) };
}
/** Holt's linear trend (optionally damped). */
export function holt(y: number[], alpha: number, beta: number, h = 0, phi = 1) {
  let l = y[0], b = y[1] - y[0]; const fitted: number[] = []; const levels: number[] = [], trends: number[] = [];
  for (const v of y) { fitted.push(l + phi * b); const lp = l; l = alpha * v + (1 - alpha) * (lp + phi * b); b = beta * (l - lp) + (1 - beta) * phi * b; levels.push(l); trends.push(b); }
  const forecast = Array.from({ length: h }, (_, i) => { let s = 0; for (let j = 1; j <= i + 1; j++) s += phi ** j; return l + s * b; });
  return { fitted, forecast, levels, trends };
}
/** Additive Holt-Winters. */
export function holtWinters(y: number[], m: number, alpha: number, beta: number, gamma: number, h = 0, multiplicative = false) {
  const n = y.length; if (n < 2 * m) return { fitted: y.slice(), forecast: Array(h).fill(y[n - 1]), season: [] as number[] };
  const first = mean(y.slice(0, m)), second = mean(y.slice(m, 2 * m));
  let l = first, b = (second - first) / m;
  const s: number[] = y.slice(0, m).map((v) => (multiplicative ? v / first : v - first));
  const fitted: number[] = [];
  for (let t = 0; t < n; t++) {
    const st = s[t % m];
    fitted.push(multiplicative ? (l + b) * st : l + b + st);
    const lp = l;
    l = multiplicative ? alpha * (y[t] / st) + (1 - alpha) * (lp + b) : alpha * (y[t] - st) + (1 - alpha) * (lp + b);
    b = beta * (l - lp) + (1 - beta) * b;
    s[t % m] = multiplicative ? gamma * (y[t] / l) + (1 - gamma) * st : gamma * (y[t] - l) + (1 - gamma) * st;
  }
  const forecast = Array.from({ length: h }, (_, i) => { const st = s[(n + i) % m]; return multiplicative ? (l + (i + 1) * b) * st : l + (i + 1) * b + st; });
  return { fitted, forecast, season: s };
}

// ── accuracy ──
export function accuracy(actual: number[], fc: number[], train?: number[], m = 1) {
  const e = actual.map((a, i) => a - fc[i]);
  const mae = mean(e.map(Math.abs));
  const rmse = Math.sqrt(mean(e.map((x) => x * x)));
  const mape = 100 * mean(e.map((x, i) => Math.abs(x / actual[i])));
  const bias = mean(e);
  let mase = NaN;
  if (train && train.length > m) {
    const sc = mean(train.slice(m).map((v, i) => Math.abs(v - train[i])));
    mase = mae / sc;
  }
  return { ME: bias, MAE: mae, RMSE: rmse, MAPE: mape, MASE: mase };
}

/** Seeded PRNG + normal draws, for reproducible simulations. */
export function rng(seed = 42) {
  let s = seed >>> 0;
  const u = () => { s = (s + 0x6d2b79f5) >>> 0; let t = s; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  const norm = () => { let a = 0, b = 0; while (a === 0) a = u(); while (b === 0) b = u(); return Math.sqrt(-2 * Math.log(a)) * Math.cos(2 * Math.PI * b); };
  return { u, norm };
}

export const fmtNum = (v: number, d = 1) => (Math.abs(v) >= 1e4 ? v.toLocaleString(undefined, { maximumFractionDigits: 0 }) : v.toLocaleString(undefined, { maximumFractionDigits: d }));
export const ym = (d: Date) => d.toLocaleDateString(undefined, { year: 'numeric', month: 'short' });
