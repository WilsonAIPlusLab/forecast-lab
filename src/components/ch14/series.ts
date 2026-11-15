// Series menu for the Forecast Studio, with display units and plain-English formatting.
// Units and SA/NSA follow DATA_CATALOG.md. `div` converts the FRED units into the display units.
export interface StudioSeries {
  id: string; label: string; noun: string; adj: 'SA' | 'NSA'; unitLong: string; unitAxis: string; div: number;
  kind: 'money' | 'count' | 'rate' | 'index'; note: string;
}

export const STUDIO_SERIES: StudioSeries[] = [
  { id: 'RSXFSN', label: 'U.S. retail sales', noun: 'U.S. retail sales excluding food services', adj: 'NSA', unitLong: '$ billions per month', unitAxis: '$ billions', div: 1000, kind: 'money', note: 'Strong December peak every year.' },
  { id: 'MRTSSM4541USS', label: 'E-commerce sales', noun: 'U.S. e-commerce sales', adj: 'SA', unitLong: '$ billions per month', unitAxis: '$ billions', div: 1000, kind: 'money', note: 'Seasonally adjusted, steep trend, a jump in 2020.' },
  { id: 'MRTSSM722USN', label: 'Restaurant & bar sales', noun: 'U.S. restaurant and bar sales', adj: 'NSA', unitLong: '$ billions per month', unitAxis: '$ billions', div: 1000, kind: 'money', note: 'Collapsed in spring 2020, then recovered.' },
  { id: 'TOTALNSA', label: 'Light vehicle sales', noun: 'U.S. light vehicle sales', adj: 'NSA', unitLong: 'thousand vehicles per month', unitAxis: 'thousand vehicles', div: 1, kind: 'count', note: 'Seasonal, with supply shocks in 2020–22.' },
  { id: 'HOUSTNSA', label: 'Housing starts', noun: 'U.S. housing starts', adj: 'NSA', unitLong: 'thousand units per month', unitAxis: 'thousand units', div: 1, kind: 'count', note: 'Low in winter, high in spring; rate-sensitive.' },
  { id: 'IPG2211A2N', label: 'Utility output', noun: 'U.S. electric and gas utility output', adj: 'NSA', unitLong: 'index, 2017 = 100', unitAxis: 'index, 2017 = 100', div: 1, kind: 'index', note: 'Two peaks a year: winter heating, summer cooling.' },
  { id: 'PAYEMS', label: 'Payroll jobs', noun: 'U.S. nonfarm payroll employment', adj: 'SA', unitLong: 'millions of jobs', unitAxis: 'millions of jobs', div: 1000, kind: 'count', note: 'Smooth trend; 22 million jobs lost in spring 2020.' },
  { id: 'UNRATE', label: 'Unemployment rate', noun: 'the U.S. unemployment rate', adj: 'SA', unitLong: 'percent', unitAxis: '%', div: 1, kind: 'rate', note: 'Wanders slowly; spiked to 14.8% in April 2020.' },
  { id: 'IAUR', label: 'Iowa unemployment rate', noun: 'the Iowa unemployment rate', adj: 'SA', unitLong: 'percent', unitAxis: '%', div: 1, kind: 'rate', note: 'A local series: Iowa, seasonally adjusted.' },
  { id: 'CPIAUCSL', label: 'Consumer prices (CPI)', noun: 'the CPI-U consumer price index', adj: 'SA', unitLong: 'index, 1982–84 = 100', unitAxis: 'index, 1982–84 = 100', div: 1, kind: 'index', note: 'Steady climb, faster in 2021–22.' },
];
export const seriesById = (id: string) => STUDIO_SERIES.find((s) => s.id === id) ?? STUDIO_SERIES[0];
export const adjText = (s: StudioSeries) => (s.adj === 'SA' ? 'seasonally adjusted' : 'not seasonally adjusted');

const nf = (v: number, d: number) => v.toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });
/** Digits that suit the size of the number (3 significant digits, at least 0, at most 2 decimals). */
export function digitsFor(v: number) { const a = Math.abs(v); return a >= 100 ? 1 : a >= 10 ? 1 : 2; }

/** Format a value in display units for prose: "$612.3 billion", "1,361 thousand vehicles", "4.3%", "index 339.2". */
export function fmtVal(s: StudioSeries, v: number, d = digitsFor(v)) {
  switch (s.id) {
    case 'RSXFSN': case 'MRTSSM4541USS': case 'MRTSSM722USN': return `$${nf(v, d)} billion`;
    case 'PAYEMS': return `${nf(v, 2)} million jobs`;
    case 'TOTALNSA': return `${nf(v, 0)} thousand vehicles`;
    case 'HOUSTNSA': return `${nf(v, 1)} thousand units`;
    case 'UNRATE': case 'IAUR': return `${nf(v, 1)}%`;
    case 'IPG2211A2N': return `${nf(v, 1)} (index, 2017 = 100)`;
    case 'CPIAUCSL': return `${nf(v, 1)} (index, 1982–84 = 100)`;
  }
  return nf(v, d);
}
/** Short value for tables, tiles and axes (no unit words). */
export function fmtShort(s: StudioSeries, v: number) {
  if (!Number.isFinite(v)) return '—';
  const a = Math.abs(v);
  const d = s.kind === 'rate' ? 2 : s.id === 'PAYEMS' ? 2 : a >= 1000 ? 0 : a >= 100 ? 1 : a >= 10 ? 1 : 2;
  return (s.kind === 'money' ? (v < 0 ? '−$' : '$') + nf(a, d) : (v < 0 ? '−' : '') + nf(a, d));
}
/** Size of a miss in words: "$9.1 billion", "0.18 percentage points". */
export function fmtMiss(s: StudioSeries, v: number) {
  const a = Math.abs(v);
  if (s.kind === 'rate') return `${nf(a, 2)} percentage points`;
  if (s.id === 'PAYEMS') return a < 1 ? `${nf(a * 1000, 0)} thousand jobs` : `${nf(a, 2)} million jobs`;
  if (s.kind === 'money') return `$${nf(a, a >= 10 ? 1 : 2)} billion`;
  if (s.kind === 'index') return `${nf(a, 2)} index points`;
  return `${nf(a, 1)} ${s.unitAxis}`;
}
export const monthYear = (d: Date) => d.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
export const monYr = (d: Date) => d.toLocaleDateString('en-US', { month: 'short', year: 'numeric' });
export const isoMonth = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
