#| **Load the two series.** `to="month"` averages the weekly claims readings in each month. Both series are seasonally adjusted.
claims = fred("ICSA", to="month")   # initial claims, monthly average, SA
jobs = fred("PAYEMS")               # nonfarm payrolls, thousands, SA

#| **Year-over-year growth, 1990 to 2019** (100 × 12-month log difference), leaving COVID out for now.
claims_yoy = (100 * np.log(claims).diff(12))["1990-01":"2019-12"]
jobs_yoy = (100 * np.log(jobs).diff(12))["1990-01":"2019-12"]
x, y = claims_yoy.values, jobs_yoy.values

#| **Cross-correlation, computed exactly as R's `ccf()` does**: full-sample means and standard deviations, divided by *n*. Lag *k* is the correlation of `x[t + k]` with `y[t]`, so negative *k* means claims move first.
n = len(x); xc, yc = x - x.mean(), y - y.mean()
def ccf_at(k):
    return (np.sum(xc[k:] * yc[:n - k]) if k >= 0 else np.sum(xc[:n + k] * yc[-k:])) / n / (x.std() * y.std())
lags = np.arange(-18, 19)
r = pd.Series([ccf_at(k) for k in lags], index=lags)
best = int(r.abs().idxmax())
print(pd.Series({"best_lag": best, "corr_at_best": r[best], "corr_same_month": r[0]}).round(2))

#| **Chart the cross-correlations** (same custom chart as the R version).
viz_custom("ch07-ccf", lag=lags.tolist(), value=r.tolist(), ci=1.96 / np.sqrt(n), best=best,
           xlab="lag k (months); negative = claims move first",
           title="Claims growth peaks about 7 months before job growth does", source="FRED (ICSA, PAYEMS)")

#| **Shift claims later by the lead and overlay.** `shift(lead)` moves the series `lead` months to the right.
lead = -best
z = lambda s: (s - s.mean()) / s.std()
viz_ts(**{"Job growth (yoy, standardized)": z(jobs_yoy),
          "Claims growth, inverted, shifted 7 months later": (-z(claims_yoy)).shift(lead, freq="MS")},
       title="Shift claims forward and they trace the path of job growth", recessions=True)
