// Build-time sparkline paths from bundled CSVs (runs in Astro frontmatter, zero client JS).
import fs from 'node:fs';
import path from 'node:path';

export function sparkPath(id: string, opts: { start?: string; w?: number; h?: number; yoy?: boolean } = {}) {
  const { start = '2005-01-01', w = 160, h = 40, yoy = false } = opts;
  const file = path.join(process.cwd(), 'public', 'data', `${id}.csv`);
  let rows = fs.readFileSync(file, 'utf8').trim().split('\n').slice(1).map((l) => l.split(',')).filter((r) => r[1] && r[1] !== '.' && r[0] >= start);
  let v = rows.map((r) => parseFloat(r[1]));
  if (yoy) v = v.slice(12).map((x, i) => (100 * (x - v[i])) / v[i]);
  if (v.length > 240) { const step = v.length / 240; v = Array.from({ length: 240 }, (_, i) => v[Math.floor(i * step)]); }
  const mn = Math.min(...v), mx = Math.max(...v);
  const pts = v.map((y, i) => `${((i / (v.length - 1)) * w).toFixed(1)},${(h - 2 - ((y - mn) / (mx - mn || 1)) * (h - 4)).toFixed(1)}`);
  return 'M' + pts.join('L');
}

/** Which real series illustrates each chapter (used for card sparklines). */
export const chapterSeries: Record<string, { id: string; yoy?: boolean; start?: string }> = {
  'first-forecast': { id: 'RSXFSN', start: '2015-01-01' },
  'time-series-data': { id: 'CPIAUCSL', yoy: true },
  decomposition: { id: 'MRTSSM448USN', start: '2012-01-01' },
  benchmarks: { id: 'HOUSTNSA', start: '2012-01-01' },
  regression: { id: 'MORTGAGE30US', start: '2000-01-01' },
  'exponential-smoothing': { id: 'MRTSSM4541USN', start: '2010-01-01' },
  arima: { id: 'CPILFESL', yoy: true },
  'dynamic-regression': { id: 'ICSA', start: '2000-01-01' },
  'recession-probability': { id: 'T10Y3M', start: '1990-01-01' },
  var: { id: 'FEDFUNDS', start: '1990-01-01' },
  uncertainty: { id: 'GASREGW', start: '2005-01-01' },
  'random-forests': { id: 'IPG2211A2N', start: '2012-01-01' },
  'boosting-shap': { id: 'MRTSSM722USN', start: '2012-01-01' },
  nowcasting: { id: 'PAYEMS', start: '2005-01-01' },
  'forecast-studio': { id: 'RSAFS', start: '2005-01-01' },
};
