#| **Load the two series.** `to="month"` averages the weekly claims readings in each month. Both series are seasonally adjusted.
claims = fred("ICSA", to="month")   # initial claims, monthly average, SA
jobs = fred("PAYEMS")               # nonfarm payrolls, thousands, SA

#| **Year-over-year growth, 1990 to 2019** (100 × 12-month log difference), leaving COVID out for now.
# .diff(12) = this month minus the same month last year; ["1990-01":"2019-12"] keeps 1990-2019
claims_yoy = (100 * np.log(claims).diff(12))["1990-01":"2019-12"]
jobs_yoy = (100 * np.log(jobs).diff(12))["1990-01":"2019-12"]
x, y = claims_yoy.values, jobs_yoy.values   # plain NumPy arrays

#| **Cross-correlation, computed exactly as R's `ccf()` does**: full-sample means and standard deviations, divided by *n*. Lag *k* is the correlation of `x[t + k]` with `y[t]`, so negative *k* means claims move first.
n = len(x); xc, yc = x - x.mean(), y - y.mean()   # demeaned series
def ccf_at(k):
    # pair x[t + k] with y[t] by slicing the two arrays against each other
    return (np.sum(xc[k:] * yc[:n - k]) if k >= 0 else np.sum(xc[:n + k] * yc[-k:])) / n / (x.std() * y.std())
lags = np.arange(-18, 19)                         # lags -18..+18
r = pd.Series([ccf_at(k) for k in lags], index=lags)   # correlations, indexed by lag
best = int(r.abs().idxmax())                      # lag with the largest |correlation|
print(pd.Series({"best_lag": best, "corr_at_best": r[best], "corr_same_month": r[0]}).round(2))

#| **Chart the cross-correlations** (same custom chart as the R version).
viz_custom("ch07-ccf", lag=lags.tolist(), value=r.tolist(), ci=1.96 / np.sqrt(n), best=best,   # ci = band half-width
           xlab="lag k (months); negative = claims move first",
           title="Claims growth peaks about 7 months before job growth does", source="FRED (ICSA, PAYEMS)")

#| **Shift claims later by the lead and overlay.** `shift(lead)` moves the series `lead` months to the right.
lead = -best                                      # lead in months (positive number)
z = lambda s: (s - s.mean()) / s.std()            # standardize: mean 0, standard deviation 1
viz_ts(**{"Job growth (yoy, standardized)": z(jobs_yoy),
          "Claims growth, inverted, shifted 7 months later": (-z(claims_yoy)).shift(lead, freq="MS")},   # flip sign; move dates forward
       title="Shift claims forward and they trace the path of job growth", recessions=True)
