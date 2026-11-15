#| **Two interest rates, 1960–2019, monthly.**
from statsmodels.tsa.stattools import adfuller, coint   # ADF unit-root test; Engle–Granger cointegration test
from statsmodels.tsa.vector_ar.vecm import coint_johansen, VECM   # Johansen test; error-correction model
g10 = fred("GS10", start="1960-01-01", end="2019-12-01")   # 10-year Treasury yield, %, monthly
tb = fred("TB3MS", start="1960-01-01", end="2019-12-01")   # 3-month Treasury bill rate, %, monthly
# spread = long minus short
viz_ts(**{"10-year": g10, "3-month": tb, "Spread": g10 - tb}, recessions=True, ylab="%",
       title="Each yield wanders; the gap between them keeps snapping back")

#| **Unit-root tests on each yield** (ADF with a constant, 4 lags, as in R). Statistics match `ur.df`; neither rejects a unit root.
adf = lambda x: adfuller(x, maxlag=4, autolag=None, regression="c")[0]   # ADF statistic: constant, fixed 4 lags
# compare with the 5% value of -2.86
print({"GS10": round(float(adf(g10)), 3), "TB3MS": round(float(adf(tb)), 3)})

#| **Engle–Granger in one call.** `coint()` runs both steps and, unlike the manual route, uses the correct Engle–Granger (MacKinnon) critical values and p-value. It picks its own lag length (by AIC) instead of our fixed 4 lags, so its statistic, −4.04, is a little more negative than R's −3.81. Both are well below the −3.34 critical value: same verdict.
stat, pval, crit = coint(g10, tb)             # statistic, p-value, critical values (1%, 5%, 10%)
print({"EG stat": round(float(stat), 3), "p-value": round(float(pval), 4), "5% crit": round(float(crit[1]), 3)})

#| **Johansen trace test.** `det_order=0` puts a constant in the relation; `k_ar_diff=3` lags of differences equal R's `K = 4` in levels. The trace statistics (31.4 and 2.6) are near R's, but the critical values are not: statsmodels lets the constant enter the short-run equations, while R's `ecdet = "const"` restricts it to the long-run relation, and each setup has its own table. The verdict is the same, one relation, though here 2.6 for *r ≤ 1* sits just under its 10% value of 2.71, a closer call than in R.
jo = coint_johansen(pd.concat([g10, tb], axis=1).values, det_order=0, k_ar_diff=3)   # .values = plain numpy array
# trace statistics (lr1) next to the 90/95/99% critical values (cvt columns)
print(pd.DataFrame({"trace": jo.lr1, "90%": jo.cvt[:, 0], "95%": jo.cvt[:, 1], "99%": jo.cvt[:, 2]}, index=["r = 0", "r <= 1"]).round(2))

#| **VECM with one cointegrating relation.** `beta` (normalized on GS10) and `alpha` (adjustment speeds) tell the same story as R: slope near 1, both yields pull toward each other.
# VECM with 1 cointegrating relation; "ci" = constant inside the long-run relation
v = VECM(pd.concat([g10, tb], axis=1), k_ar_diff=3, coint_rank=1, deterministic="ci").fit()
print("beta:", v.beta.ravel().round(3), " alpha:", v.alpha.ravel().round(4))   # ravel() flattens to 1-D
