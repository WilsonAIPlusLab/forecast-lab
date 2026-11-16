// Precomputed results for the Chapter 0 explorables (written by src/labs/ch00/make_data.R).
import raw from './ch00data.json';

export interface Fan { date: Date[]; mean: number[]; lo80: number[]; hi80: number[]; lo95: number[]; hi95: number[]; model: string }
export interface PastFan extends Fan { origin: number; actual: number[] }

const d = (s: string) => new Date(s + 'T00:00:00');
const fan = (f: any): Fan => ({ ...f, date: (f.date as string[]).map(d), model: String(f.model).trim() });

/** Retail sales (RSXFSN, $ millions, NSA), Jan 2012 onward. */
export const history = (raw.history.date as string[]).map((s, i) => ({ date: d(s), value: raw.history.value[i] as number }));
/** Today's 24-month forecast: the same auto.arima model as the chapter's first lab. */
export const now: Fan = fan(raw.now);
/** Forecasts made at the end of earlier years, with what actually happened. */
export const past: PastFan[] = (raw.past as any[]).map((p) => ({ ...fan(p), origin: p.origin, actual: p.actual }));

/** $ millions -> "$738 billion" style text. */
export const bn = (v: number, digits = 0) => `$${(v / 1000).toLocaleString('en-US', { maximumFractionDigits: digits, minimumFractionDigits: digits })} billion`;
export const bnShort = (v: number) => `$${Math.round(v / 1000).toLocaleString('en-US')}B`;
export const monthName = (dt: Date, long = true) => dt.toLocaleDateString('en-US', { month: long ? 'long' : 'short', year: 'numeric' });
