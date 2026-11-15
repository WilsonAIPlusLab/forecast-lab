#| **Annual job growth, 1960 to 2019**: average payrolls in each calendar year, then the % change.
from scipy import stats
jobs = fred("PAYEMS")
annual = jobs.resample("YS").mean()
g = (100 * np.log(annual).diff())["1960":"2019"]
y = g.values; n = len(y)

#| **A Chow F-statistic at every candidate break**, trimming 15% at each end like `strucchange::Fstats(from = 0.15)`. Break at position *i* means the first regime is observations 1 to *i*. For a mean shift there is one restriction, so F = (RSS₁ − RSS₂) / (RSS₂ / (n − 2)).
rss = lambda v: np.sum((v - v.mean())**2)
lo = int(np.floor(0.15 * n)); hi = n - lo
F = pd.Series({g.index[i - 1].year: (rss(y) - rss(y[:i]) - rss(y[i:])) / ((rss(y[:i]) + rss(y[i:])) / (n - 2)) for i in range(lo, hi + 1)})
print(f"sup-F = {F.max():.1f} in {F.idxmax()}")

#| **Plot the curve with the 5% sup-F critical value.** statsmodels has no Andrews critical values, so we use the one R's `boundary()` returns for this sample (8.61). It is far above the ordinary F critical value of about 4.
crit = 8.61
idx = pd.to_datetime([f"{yr}-01-01" for yr in F.index])
viz_ts(**{"Chow F-statistic": pd.Series(F.values, index=idx), "5% critical value (sup-F)": pd.Series(crit, index=idx)},
       title="The F-statistic peaks at 2000: job growth downshifted", ylab="F-statistic")

#| **Measure the break** (one break = the date with the smallest combined RSS, which is the sup-F date).
b = F.idxmax()
print(pd.Series({f"1960–{b}": g[:str(b)].mean(), f"{b + 1}–2019": g[str(b + 1):].mean()}).round(2))

#| **The price of searching.** If 2000 had been chosen in advance, the ordinary F-test p-value would apply. It is roughly ten times smaller than the honest sup-F p-value (0.015 in R).
print("naive Chow p-value:", round(stats.f.sf(F.max(), 1, n - 2), 4))

#| **COVID: the same search on the monthly claims–jobs link, 2010 to 2024.** Two coefficients (intercept and slope) can break, so the statistic sums over two restrictions, as `strucchange` does.
claims = fred("ICSA", to="month")
d = pd.DataFrame({"dj": jobs.diff(), "dcl": 100 * np.log(claims).diff()}).dropna()["2010-01":"2024-12"]
X = np.column_stack([np.ones(len(d)), d["dcl"]]); Y = d["dj"].values; m = len(d)
def rss_ols(X, Y): return np.sum((Y - X @ np.linalg.lstsq(X, Y, rcond=None)[0])**2)
lo = int(np.floor(0.15 * m))
Fm = pd.Series({d.index[i - 1]: (rss_ols(X, Y) - rss_ols(X[:i], Y[:i]) - rss_ols(X[i:], Y[i:])) /
                ((rss_ols(X[:i], Y[:i]) + rss_ols(X[i:], Y[i:])) / (m - 4)) for i in range(lo, m - lo + 1)})
print(Fm["2019-12":"2020-06"].round(1))

#| **Ignore COVID, one dummy, pulse dummies, or drop the months.** A single dummy leaves the slope distorted; pulse dummies and dropping give the same slope.
covid = (d.index >= "2020-03-01") & (d.index < "2022-01-01")
pulses = np.column_stack([(np.arange(m) == i).astype(float) for i in np.where(covid)[0]])
slope = lambda X, Y: np.linalg.lstsq(X, Y, rcond=None)[0][1]
print(pd.Series({"ignore_covid": slope(X, Y), "one_dummy": slope(np.column_stack([X, covid.astype(float)]), Y), "pulse_dummies": slope(np.column_stack([X, pulses]), Y),
                 "drop_covid": slope(X[~covid], Y[~covid])}).round(2))
