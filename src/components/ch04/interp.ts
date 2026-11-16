// Pure helpers for the Chapter 4 coefficient-interpretation explorables (no DOM, no fetch: testable in Node).
import { ols, joinMonthly, type OLS } from './ols';

export interface CarRow { date: Date; veh: number; gas: number; un: number; mr: number; chip: number }

/** Join monthly car sales and drivers, January 1993 onward, with the 2021–22 chip-shortage dummy (as in the labs). */
export function carRows(veh: { date: Date; value: number }[], gas: { date: Date; value: number }[],
  un: { date: Date; value: number }[], mr: { date: Date; value: number }[]): CarRow[] {
  return joinMonthly([veh, gas, un, mr]).filter((r) => r.date.getFullYear() >= 1993).map((r) => ({
    date: r.date, veh: r.v[0], gas: r.v[1], un: r.v[2], mr: r.v[3], chip: [2021, 2022].includes(r.date.getFullYear()) ? 1 : 0,
  }));
}

/** Fit sales ~ gas + un + mr + chip with sales and/or gas in logs. Returns the fit; beta[1] is the gas coefficient. */
export function fitForm(rows: CarRow[], yLog: boolean, xLog: boolean): OLS {
  const X = rows.map((r) => [1, xLog ? Math.log(r.gas) : r.gas, r.un, r.mr, r.chip]);
  return ols(X, rows.map((r) => (yLog ? Math.log(r.veh) : r.veh)));
}

/** Newey–West (Bartlett kernel, fixed lag L, no prewhitening, no small-sample scaling) covariance,
 *  like R's sandwich::NeweyWest(lag = L, prewhite = FALSE) and statsmodels' HAC with maxlags = L. */
export function neweyWest(X: number[][], f: OLS, L: number): number[][] {
  const { n, p } = f;
  const S: number[][] = Array.from({ length: p }, () => Array(p).fill(0));
  const g = X.map((x, t) => x.map((v) => v * f.resid[t]));   // score contributions x_t * e_t
  for (let l = 0; l <= L; l++) {
    const w = l === 0 ? 1 : 1 - l / (L + 1);
    for (let t = l; t < n; t++) for (let i = 0; i < p; i++) for (let j = 0; j < p; j++) {
      const v = g[t][i] * g[t - l][j];
      S[i][j] += w * v;
      if (l > 0) S[j][i] += w * v;
    }
  }
  const A = f.XtXinv;
  const AS = A.map((r) => S[0].map((_, j) => r.reduce((s, a, k) => s + a * S[k][j], 0)));
  return AS.map((r) => A[0].map((_, j) => r.reduce((s, a, k) => s + a * A[k][j], 0)));
}

/** Regress y on [1, ...controls] and return the residuals (Frisch–Waugh "partialling out"). */
export function partialOut(y: number[], controls: number[][]): number[] {
  const X = y.map((_, i) => [1, ...controls.map((c) => c[i])]);
  return ols(X, y).resid;
}
