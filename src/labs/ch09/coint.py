#| **Two interest rates, 1960–2019, monthly.**
from statsmodels.tsa.stattools import adfuller, coint
from statsmodels.tsa.vector_ar.vecm import coint_johansen, VECM
g10 = fred("GS10", start="1960-01-01", end="2019-12-01")
tb = fred("TB3MS", start="1960-01-01", end="2019-12-01")
viz_ts(**{"10-year": g10, "3-month": tb, "Spread": g10 - tb}, recessions=True, ylab="%",
       title="Each yield wanders; the gap between them keeps snapping back")

#| **Unit-root tests on each yield** (ADF with a constant, 4 lags, as in R). Statistics match `ur.df`; neither rejects a unit root.
adf = lambda x: adfuller(x, maxlag=4, autolag=None, regression="c")[0]
print({"GS10": round(float(adf(g10)), 3), "TB3MS": round(float(adf(tb)), 3)})

#| **Engle–Granger in one call.** `coint()` runs both steps and, unlike the manual route, uses the correct Engle–Granger (MacKinnon) critical values and p-value. It picks its own lag length (by AIC) instead of our fixed 4 lags, so its statistic, −4.04, is a little more negative than R's −3.81. Both are well below the −3.34 critical value: same verdict.
stat, pval, crit = coint(g10, tb)
print({"EG stat": round(float(stat), 3), "p-value": round(float(pval), 4), "5% crit": round(float(crit[1]), 3)})

#| **Johansen trace test.** `det_order=0` puts a constant in the relation; `k_ar_diff=3` lags of differences equal R's `K = 4` in levels. The trace statistics (31.4 and 2.6) are near R's, but the critical values are not: statsmodels lets the constant enter the short-run equations, while R's `ecdet = "const"` restricts it to the long-run relation, and each setup has its own table. The verdict is the same, one relation, though here 2.6 for *r ≤ 1* sits just under its 10% value of 2.71, a closer call than in R.
jo = coint_johansen(pd.concat([g10, tb], axis=1).values, det_order=0, k_ar_diff=3)
print(pd.DataFrame({"trace": jo.lr1, "90%": jo.cvt[:, 0], "95%": jo.cvt[:, 1], "99%": jo.cvt[:, 2]}, index=["r = 0", "r <= 1"]).round(2))

#| **VECM with one cointegrating relation.** `beta` (normalized on GS10) and `alpha` (adjustment speeds) tell the same story as R: slope near 1, both yields pull toward each other.
v = VECM(pd.concat([g10, tb], axis=1), k_ar_diff=3, coint_rank=1, deterministic="ci").fit()
print("beta:", v.beta.ravel().round(3), " alpha:", v.alpha.ravel().round(4))
