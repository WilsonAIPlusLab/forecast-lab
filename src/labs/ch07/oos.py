#| **The forecasting table.** Target: jobs added in month *t*. Known at forecast time: jobs added in *t − 1* and *t − 2*, and claims growth through *t − 1*. Same-month claims make a **nowcast**.
claims = fred("ICSA", to="month"); jobs = fred("PAYEMS")   # initial claims (monthly avg) and payrolls, SA
dj = jobs.diff(); dcl = 100 * np.log(claims).diff()        # jobs added (thousands); % change in claims
# .shift(1) moves a series one month later, so row t holds the value from t - 1
X = pd.DataFrame({"dj": dj, "dj1": dj.shift(1), "dj2": dj.shift(2), "dcl1": dcl.shift(1), "dcl0": dcl}).dropna()
X = X[X.index >= "1990-01-01"]                             # keep 1990 onward
covid = (X.index >= "2020-03-01") & (X.index < "2022-01-01")   # True for March 2020 to December 2021

#| **Expanding-window, one-step-ahead forecasts by OLS** (`np.linalg.lstsq`), the same models as the R version.
def oos(vars, start, end, drop_covid=False):
    Z = np.column_stack([np.ones(len(X)), X[vars].values]); y = X["dj"].values   # Z = intercept + chosen predictors
    errs = []
    for i in np.where((X.index >= start) & (X.index <= end))[0]:   # each target month in the test window
        train = np.arange(i)                       # rows 0 .. i-1: everything before month i
        if drop_covid: train = train[~covid[train]]   # optionally remove pandemic months
        b = np.linalg.lstsq(Z[train], y[train], rcond=None)[0]   # OLS coefficients on the training rows
        errs.append(y[i] - Z[i] @ b)               # forecast error: actual minus prediction
    return np.array(errs)
models = {"AR": ["dj1", "dj2"], "AR + claims(t-1)": ["dj1", "dj2", "dcl1"], "AR + claims(t) nowcast": ["dj1", "dj2", "dcl0"]}   # benchmark, forecast, nowcast

#| **Four test windows.**
end = X.index.max()                                        # latest month in the data
# each window = (first month, last month, drop COVID from training?)
windows = {"Calm 2010–19": ("2010-01", "2019-12", False), "Recession 2007–10": ("2007-01", "2010-12", False),
           "2022+, COVID in training": ("2022-01", end, False), "2022+, COVID dropped": ("2022-01", end, True)}
errs = {w: {m: oos(v, pd.Timestamp(a), pd.Timestamp(b), c) for m, v in models.items()} for w, (a, b, c) in windows.items()}   # errors per window, per model
score = pd.DataFrame({w: {m: np.sqrt(np.mean(e**2)) for m, e in em.items()} for w, em in errs.items()})   # RMSE: rows = models, columns = windows
print(score.round(1))

#| **Diebold–Mariano test** for one-step forecasts, written out: the t-statistic of the mean loss difference, with R's small-sample correction (Harvey, Leybourne and Newbold, 1997) as in `dm.test()`.
from scipy import stats
def dm_p(e1, e2):
    d = e1**2 - e2**2; n = len(d)                          # loss difference (squared errors) each month
    stat = d.mean() / np.sqrt(np.var(d) / n) * np.sqrt((n - 1) / n)   # t-statistic with the small-sample correction
    return 2 * stats.t.sf(abs(stat), n - 1)                # two-sided p-value from the t distribution
print(pd.DataFrame({w: {"claims(t-1) vs AR": dm_p(em["AR"], em["AR + claims(t-1)"]),
                        "nowcast vs AR": dm_p(em["AR"], em["AR + claims(t) nowcast"])} for w, em in errs.items()}).round(3))

#| **The scorecard**: green = best model in each test window.
viz_table(score, highlight=list(windows), digits=1,        # highlight the lowest RMSE in every column
          title="Claims help most as a nowcast in a downturn; COVID data poison the fit")
