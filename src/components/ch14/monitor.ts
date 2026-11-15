// Forecast monitoring after deployment: one-step forecasts with frozen parameters, a tracking signal, retraining triggers.
import { holt, holtWinters, mean } from '../../lib/ts';
import { fitForecast } from './engine';

export interface MonitorStep { i: number; y: number; f: number; e: number; ts: number; alarm: boolean; retrained: boolean }
export interface MonitorRun { steps: MonitorStep[]; alarms: number[]; mae: number; me: number }

/** One-step-ahead forecast for y[t] from a model with fixed parameters, run over y[0..t-1]. */
function oneStep(kind: 'holt' | 'hwm', y: number[], p: Record<string, number>, t: number) {
  const tr = y.slice(0, t);
  return kind === 'holt' ? holt(tr, p.alpha, p.beta, 1, p.phi).forecast[0] : holtWinters(tr, 12, p.alpha, p.beta, p.gamma, 1, true).forecast[0];
}

/**
 * Deploy a model fitted on y[0..t0-1]; each month forecast one step ahead, record the error, update the
 * tracking signal TS = (running sum of errors) / (mean absolute error), both since the last (re)fit.
 * If |TS| > threshold an alarm fires; with retrain = true the parameters are re-estimated and the counters reset.
 */
export function monitor(y: number[], t0: number, kind: 'holt' | 'hwm', threshold: number, retrain: boolean): MonitorRun {
  let p = fitForecast(kind, y.slice(0, t0), 1, 12).params!;
  let rsfe = 0, sabs = 0, n = 0;
  const steps: MonitorStep[] = [], alarms: number[] = [];
  for (let t = t0; t < y.length; t++) {
    const f = oneStep(kind, y, p, t), e = y[t] - f;
    rsfe += e; sabs += Math.abs(e); n++;
    const ts = rsfe / (sabs / n);
    const alarm = n >= 2 && Math.abs(ts) > threshold;
    let retrained = false;
    if (alarm) {
      alarms.push(t);
      if (retrain) { p = fitForecast(kind, y.slice(0, t + 1), 1, 12).params!; retrained = true; }
      rsfe = 0; sabs = 0; n = 0; // after an alarm the analyst investigates and the counters restart
    }
    steps.push({ i: t, y: y[t], f, e, ts, alarm, retrained });
  }
  return { steps, alarms, mae: mean(steps.map((s) => Math.abs(s.e))), me: mean(steps.map((s) => s.e)) };
}
