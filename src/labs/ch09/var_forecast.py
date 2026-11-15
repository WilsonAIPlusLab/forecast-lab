#| **Same three series**, kept through 2002.
from statsmodels.tsa.api import VAR           # vector autoregression model
from statsmodels.tsa.ar_model import AutoReg  # univariate autoregression, AR(p)
q = lambda i: fred(i, to="quarter")           # helper: FRED series as quarterly averages
# full data: inflation (annualized %), unemployment, funds rate; common quarters only
d = pd.concat({"infl": 400 * np.log(q("CPIAUCSL")).diff(), "unemp": q("UNRATE"), "ffr": q("FEDFUNDS")}, axis=1).dropna()
d.index.freq = "QS"                           # quarterly data (quarter-start dates)
y = d["1960-01-01":"2000-12-31"]              # estimation sample; 2001 onward is held back

#| **One forecast as a fan.** `forecast_interval()` returns the point forecast and 95% bounds for every variable, 8 quarters ahead (column 1 = unemployment).
m = VAR(y).fit(4)                             # VAR(4) with a constant
# start from the last 4 quarters; 95% bounds
mid, lo, hi = m.forecast_interval(y.values[-4:], steps=8, alpha=0.05)
idx = pd.date_range("2001-01-01", periods=8, freq="QS")   # dates for the 8 forecast quarters
viz_forecast(y["unemp"], pd.Series(mid[:, 1], idx), lower=pd.Series(lo[:, 1], idx), upper=pd.Series(hi[:, 1], idx),
             # overlay 2001-02 actuals
             actual=d["unemp"]["2001-01-01":"2002-12-31"], from_="1995-01-01", method="VAR(4)",
             title="The VAR saw unemployment rising, but the 2001 recession doubled the rise")

#| **Roll the origin**: refit at every quarter 1990Q4–1999Q4, forecast 4 quarters ahead with the VAR(4), an AR(4) per variable (`AutoReg`) and naive.
H, rows = 4, []                               # horizon 4 quarters; rows collects one dict per error
# row positions of the forecast origins 1990Q4 to 1999Q4 (list comprehension)
ends = [i for i, t in enumerate(y.index) if pd.Timestamp("1990-10-01") <= t <= pd.Timestamp("1999-10-01")]
for e in ends:                                # rolling-origin evaluation: one pass per origin
    tr, act = y.iloc[: e + 1], y.iloc[e + H]  # training data up to the origin; actual values H quarters later
    fv = VAR(tr).fit(4).forecast(tr.values[-4:], H)[-1]   # refit the VAR; keep the H-step forecast
    for j, v in enumerate(y.columns):
        fa = AutoReg(tr[v].values, lags=4).fit().forecast(H)[-1]   # AR(4) for this variable alone
        # forecast errors (actual minus forecast) for VAR, AR and naive (last value)
        rows.append({"var": v, "VAR(4)": act[v] - fv[j], "AR(4)": act[v] - fa, "Naive": act[v] - tr[v].iloc[-1]})

#| **The scorecard (RMSE, percentage points).** Identical to the R version: the VAR wins only for the funds rate.
err = pd.DataFrame(rows)                      # one row per (origin, variable)
# RMSE per variable and method; .T flips so rows = methods, columns = variables
rmse = err.groupby("var")[["VAR(4)", "AR(4)", "Naive"]].apply(lambda e: np.sqrt((e**2).mean())).T[list(y.columns)]
viz_table(rmse, highlight=list(y.columns), digits=3, title="One year ahead, 1991–2000: the VAR wins only for the funds rate")
print(rmse.round(4))                          # lower is better
