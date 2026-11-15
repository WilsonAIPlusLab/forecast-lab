#| **One spurious regression**: two independent random walks, regressed on each other. `default_rng(1974)` makes the draws reproducible (NumPy's generator differs from R's, so the exact numbers differ; the percentages are close).
import statsmodels.api as sm
rng = np.random.default_rng(1974)          # seeded random generator: same draws every run
n = 100                                    # observations per series
x = np.cumsum(rng.standard_normal(n))      # random walk: running total of normal shocks
y = np.cumsum(rng.standard_normal(n))      # a second, completely independent random walk
fit = sm.OLS(y, sm.add_constant(x)).fit()  # regress y on x anyway
print({"slope_t": round(float(fit.tvalues[1]), 2), "r_squared": round(float(fit.rsquared), 2)})   # tvalues[1] = slope's t

#| **The fast t-statistic**: t = r·√((n − 2)/(1 − r²)) gives the same answer as OLS.
def t_stat(x, y):
    r = np.corrcoef(x, y)[0, 1]            # correlation between x and y
    return r * np.sqrt((len(x) - 2) / (1 - r**2))
print(round(t_stat(x, y), 4))              # same value as OLS above

#| **1,000 repetitions, levels vs differences.**
def one_run(n=100):                        # one experiment: two new independent random walks
    x = np.cumsum(rng.standard_normal(n)); y = np.cumsum(rng.standard_normal(n))
    return t_stat(x, y), t_stat(np.diff(x), np.diff(y))   # t in levels and in first differences
sims = pd.DataFrame([one_run() for _ in range(1000)], columns=["levels", "differences"])   # 1,000 rows
share_significant = (sims.abs() > 2).mean()   # share of runs with |t| > 2 in each column
print(share_significant.round(3))
print((sims**2 / (sims**2 + 98)).median().round(3))   # median R-squared

#| **Headline numbers.**
viz_kpi(**{"Levels: share with |t| > 2": f"{100 * share_significant['levels']:.0f}%",   # format as a whole %
           "Differences: share with |t| > 2": f"{100 * share_significant['differences']:.0f}%", "Should be": "5%"})

#| **The distribution of t-statistics.**
viz_custom("ch07-hist", levels=sims["levels"].tolist(), differences=sims["differences"].tolist(), cutoff=2,
           xlab="t-statistic on the slope", title="In levels, 'significant' is the rule, not the exception",
           source="Simulation: 1,000 pairs of independent random walks, n = 100")

#| **More data makes it worse.**
sizes = [25, 50, 100, 200, 400]            # sample sizes to try
# for each size m: 300 runs, share of levels regressions ([0]) with |t| > 2
rate = [np.mean([abs(one_run(m)[0]) > 2 for _ in range(300)]) for m in sizes]
print(pd.Series(100 * np.array(rate), index=sizes).round())   # false-alarm rate in %, by sample size
viz_lines(sizes, **{"Levels (random walks)": 100 * np.array(rate), "Nominal 5% rate": [5] * len(sizes)},
          xlab="sample size n", ylab="% of regressions with |t| > 2", zero=True,
          title="With random walks, more data means more false discoveries")
