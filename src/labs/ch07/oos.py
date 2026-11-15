#| **The forecasting table.** Target: jobs added in month *t*. Known at forecast time: jobs added in *t − 1* and *t − 2*, and claims growth through *t − 1*. Same-month claims make a **nowcast**.
claims = fred("ICSA", to="month"); jobs = fred("PAYEMS")
dj = jobs.diff(); dcl = 100 * np.log(claims).diff()
X = pd.DataFrame({"dj": dj, "dj1": dj.shift(1), "dj2": dj.shift(2), "dcl1": dcl.shift(1), "dcl0": dcl}).dropna()
X = X[X.index >= "1990-01-01"]
covid = (X.index >= "2020-03-01") & (X.index < "2022-01-01")

#| **Expanding-window, one-step-ahead forecasts by OLS** (`np.linalg.lstsq`), the same models as the R version.
def oos(vars, start, end, drop_covid=False):
    Z = np.column_stack([np.ones(len(X)), X[vars].values]); y = X["dj"].values
    errs = []
    for i in np.where((X.index >= start) & (X.index <= end))[0]:
        train = np.arange(i)
        if drop_covid: train = train[~covid[train]]
        b = np.linalg.lstsq(Z[train], y[train], rcond=None)[0]
        errs.append(y[i] - Z[i] @ b)
    return np.array(errs)
models = {"AR": ["dj1", "dj2"], "AR + claims(t-1)": ["dj1", "dj2", "dcl1"], "AR + claims(t) nowcast": ["dj1", "dj2", "dcl0"]}

#| **Four test windows.**
end = X.index.max()
windows = {"Calm 2010–19": ("2010-01", "2019-12", False), "Recession 2007–10": ("2007-01", "2010-12", False),
           "2022+, COVID in training": ("2022-01", end, False), "2022+, COVID dropped": ("2022-01", end, True)}
errs = {w: {m: oos(v, pd.Timestamp(a), pd.Timestamp(b), c) for m, v in models.items()} for w, (a, b, c) in windows.items()}
score = pd.DataFrame({w: {m: np.sqrt(np.mean(e**2)) for m, e in em.items()} for w, em in errs.items()})
print(score.round(1))

#| **Diebold–Mariano test** for one-step forecasts, written out: the t-statistic of the mean loss difference, with R's small-sample correction (Harvey, Leybourne and Newbold, 1997) as in `dm.test()`.
from scipy import stats
def dm_p(e1, e2):
    d = e1**2 - e2**2; n = len(d)
    stat = d.mean() / np.sqrt(np.var(d) / n) * np.sqrt((n - 1) / n)
    return 2 * stats.t.sf(abs(stat), n - 1)
print(pd.DataFrame({w: {"claims(t-1) vs AR": dm_p(em["AR"], em["AR + claims(t-1)"]),
                        "nowcast vs AR": dm_p(em["AR"], em["AR + claims(t) nowcast"])} for w, em in errs.items()}).round(3))

#| **The scorecard**: green = best model in each test window.
viz_table(score, highlight=list(windows), digits=1,
          title="Claims help most as a nowcast in a downturn; COVID data poison the fit")
