// Turns a Studio run into a plain-English executive summary: bottom line first, range, track record, one risk, one trigger.
import { modelInfo, type ModelKey, type StudioResult } from './engine';
import { adjText, fmtVal, fmtMiss, monthYear, type StudioSeries } from './series';

export interface SummaryInput {
  s: StudioSeries; res: StudioResult; featured: ModelKey;
  lastDate: Date; targetDate: Date; evalStart: Date; evalEnd: Date;
  point: number; lo80: number; hi80: number; latest: number;
}
export interface Summary { text: string; risk: string; riskKind: string; changePct: number }

const COVID_START = new Date('2020-03-01T00:00:00'), COVID_END = new Date('2020-12-01T00:00:00');

export function riskFor(i: SummaryInput): { kind: string; text: string } {
  const { s, res, featured } = i;
  const sc = res.scores.find((x) => x.k === featured)!;
  const ranked = res.scores.slice().sort((a, b) => a.MAE - b.MAE);
  const name = modelInfo(featured).label;
  if (i.evalStart <= COVID_END && i.evalEnd >= COVID_START)
    return { kind: 'covid', text: `the track record includes the COVID-19 shock of 2020. Those huge misses make the range wide; if you think a shock of that size is unlikely in the next ${res.H} months, treat the range as conservative.` };
  if (modelInfo(ranked[0].k).kind === 'benchmark')
    return { kind: 'benchmark', text: `no model beat the simple ${modelInfo(ranked[0].k).label.toLowerCase()} rule over this period, so the series has little pattern a model can exploit beyond its latest values.` };
  if (Math.abs(sc.ME) > 0.4 * sc.MAE)
    return { kind: 'bias', text: `${name} has tended to ${sc.ME > 0 ? 'under' : 'over'}-forecast, by about ${fmtMiss(s, sc.ME)} on average. If that pattern continues, the outcome will land ${sc.ME > 0 ? 'above' : 'below'} our central number.` };
  if (ranked.length > 1 && ranked[1].MAE < 1.05 * ranked[0].MAE)
    return { kind: 'tie', text: `the two best methods (${modelInfo(ranked[0].k).label} and ${modelInfo(ranked[1].k).label}) are within 5% of each other, so the ranking is not decisive. A combination is a sensible hedge.` };
  const halfWidth = (i.hi80 - i.lo80) / 2 / Math.abs(i.point);
  if (s.kind !== 'rate' && halfWidth > 0.08)
    return { kind: 'wide', text: `the 80% range is wide, about ±${Math.round(halfWidth * 100)}% of the central forecast, so plans should work anywhere in it.` };
  return { kind: 'default', text: `the forecast assumes recent patterns continue. A recession, a policy change or a data revision could push the outcome outside the range.` };
}

export function makeSummary(i: SummaryInput): Summary {
  const { s, res, featured } = i;
  const sc = res.scores.find((x) => x.k === featured)!;
  const best = res.best;
  const H = res.H;
  const changePct = (i.point / i.latest - 1) * 100;
  const change = s.kind === 'rate'
    ? `${Math.abs(i.point - i.latest) < 0.05 ? 'roughly unchanged from' : `${(i.point - i.latest > 0 ? 'up' : 'down')} ${Math.abs(i.point - i.latest).toFixed(1)} percentage points from`} ${i.latest.toFixed(1)}% in ${monthYear(i.lastDate)}`
    : `${Math.abs(changePct) < 0.5 ? 'about the same as' : `${Math.abs(changePct).toFixed(1)}% ${changePct > 0 ? 'above' : 'below'}`} the latest value (${monthYear(i.lastDate)})`;
  const vsRef = 1 - sc.MAE / res.ref.MAE;
  const refPhrase = featured === 'snaive' ? '' :
    vsRef >= 0 ? `, ${Math.round(vsRef * 100)}% smaller than the “same month last year” rule` : `, ${Math.round(-vsRef * 100)}% larger than the “same month last year” rule`;
  const who = featured === best
    ? `the most accurate of the ${res.scores.length} methods we tested was ${modelInfo(best).label}`
    : `we use ${modelInfo(featured).label} (the most accurate of the ${res.scores.length} methods we tested was ${modelInfo(best).label})`;
  const risk = riskFor(i);
  const text =
    `We expect ${s.noun} (${adjText(s)}) to be about ${fmtVal(s, i.point)} in ${monthYear(i.targetDate)}, ${change}. ` +
    `Our 80% range is ${fmtVal(s, i.lo80)} to ${fmtVal(s, i.hi80)}. ` +
    `Over the past ${res.K} monthly forecast origins, ${who}: its typical miss was ${fmtMiss(s, sc.maeH[0])} one month ahead and ${fmtMiss(s, sc.maeH[H - 1])} ${H} months ahead${refPhrase}. ` +
    `Key risk: ${risk.text} ` +
    `We will revisit this forecast if actual values fall outside the 80% range two months in a row.`;
  return { text, risk: risk.text, riskKind: risk.kind, changePct };
}
