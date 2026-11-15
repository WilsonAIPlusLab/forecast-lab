// Small helpers shared by the Chapter 1 explorables.
import type { Series } from '../../lib/ts';
import { BASE } from '../../lib/runtime/status';

export interface GridPt { date: Date; value: number }

/** Put a monthly series on a complete month grid, so a missing month (e.g. Oct 2025) becomes NaN instead of vanishing. */
export function monthGrid(s: Series): GridPt[] {
  if (!s.data.length) return [];
  const byKey = new Map(s.data.map((p) => [mkey(p.date), p.value]));
  const first = s.data[0].date, last = s.data[s.data.length - 1].date;
  const out: GridPt[] = [];
  for (let y = first.getFullYear(), m = first.getMonth(); y < last.getFullYear() || (y === last.getFullYear() && m <= last.getMonth()); m++) {
    if (m === 12) { m = 0; y++; }
    const d = new Date(y, m, 1);
    out.push({ date: d, value: byKey.get(mkey(d)) ?? NaN });
  }
  return out;
}

export const mkey = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
export const monthLabel = (d: Date) => d.toLocaleDateString('en-US', { year: 'numeric', month: 'short' });
export const signed = (v: number, digits = 1) => (v > 0 ? '+' : v < 0 ? '−' : '') + Math.abs(v).toFixed(digits);
export const reducedMotion = () => typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
export const avg = (a: number[]) => a.reduce((s, v) => s + v, 0) / a.length;

/**
 * Load a monthly series exactly as published: a complete month grid with unpublished months as NaN.
 * (loadSeries, like fred(), fills short gaps by interpolation; this chapter is about seeing them.)
 */
const rawCache = new Map<string, Promise<GridPt[]>>();
export function loadPublished(id: string): Promise<GridPt[]> {
  if (!rawCache.has(id)) rawCache.set(id, (async () => {
    const txt = await (await fetch(`${BASE}data/${id}.csv`)).text();
    const data = txt.trim().split(/\r?\n/).slice(1).map((l) => { const [d, v] = l.split(','); return { date: new Date(d + 'T00:00:00'), value: parseFloat(v) }; })
      .filter((p) => Number.isFinite(p.value));
    return monthGrid({ id, freq: 12, data });
  })());
  return rawCache.get(id)!;
}
