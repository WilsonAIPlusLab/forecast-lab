#| **Rebuild the 20-series panel** in compact form, stopping in December 2019 for a clean pre-COVID test.
# series in levels: turn into monthly % growth rates
growth = ["PAYEMS", "IANA", "INDPRO", "HOUST", "PERMIT", "DSPIC96", "TOTALSA", "PCE", "RSFSXMV",
          "RSMVPD", "RSFHFS", "RSEAS", "RSDBS", "RSCCAS", "RSFSDP", "ICSA", "CCSA"]
changes = ["AWHMAN", "BAA10Y", "NFCI"]                 # hours, spreads, indexes: use plain monthly changes
# helper: download one series and make it stationary
def transform1(id):
    x = fred(id, to="month" if id in ["ICSA", "CCSA", "BAA10Y", "NFCI"] else None)   # weekly/daily -> monthly
    return 100 * np.log(x).diff() if id in growth else x.diff()   # % growth (100 x log change) or simple change
# transform all 20, glue as columns (dict keys become names), keep 1993-2019 months with all 20
panel = pd.concat({id: transform1(id) for id in growth + changes}, axis=1, sort=True).loc["1993-01":"2019-12"].dropna()
X, dates = panel.values, panel.index                   # plain numeric array + month dates

#| **Factors in real time**: standardize with data up to the origin only, clip at ±4, then take the first two principal components (via SVD, which is what PCA does inside).
def factors_at(o, k=2):
    Xo = X[: o + 1]                                    # rows 0..o only (no future data)
    Z = np.clip((Xo - Xo.mean(0)) / Xo.std(0, ddof=1), -4, 4)   # standardize each column, clip at +/-4
    Z = Z - Z.mean(0)                                  # re-center after clipping, as prcomp does
    U, s, Vt = np.linalg.svd(Z, full_matrices=False)   # singular value decomposition
    return U[:, :k] * s[:k]                            # first k principal-component scores (factors)

#| **Diffusion-index forecast vs AR(2)** for next month's industrial production growth, re-fit at each origin from Jan 2005 to Nov 2019. (Python indexes from 0, so origin `o` here is row `o + 1` in R.)
# helper: OLS with an intercept, then predict for one new row
def ols_predict(Xtr, y, xnew):
    A = np.column_stack([np.ones(len(Xtr)), Xtr])      # add a column of 1s for the intercept
    b = np.linalg.lstsq(A, y, rcond=None)[0]           # least-squares coefficients
    return b[0] + xnew @ b[1:]                         # intercept + slopes x new values (@ = matrix product)
g = panel["INDPRO"].values                             # IP growth, % per month
origins = np.where((dates >= "2005-01-01") & (dates <= "2019-11-01"))[0]   # positions of the forecast origins
rows = []
for o in origins:
    F = factors_at(o)                                  # factors estimated with data up to o
    i = np.arange(2, o)                            # rows with a known next-month outcome
    base = np.column_stack([g[i], g[i - 1]])           # AR(2) predictors: this and last month's growth
    full = np.column_stack([base, F[i, 0], F[i, 1]])   # same plus the two factors
    rows.append({"actual": g[o + 1],                   # what IP growth turned out to be
                 "AR": ols_predict(base, g[i + 1], np.array([g[o], g[o - 1]])),
                 "Factor": ols_predict(full, g[i + 1], np.array([g[o], g[o - 1], F[o, 0], F[o, 1]]))})
res = pd.DataFrame(rows, index=dates[origins + 1])     # one row per target month
print(len(res))                                        # number of origins (179)

#| **Score it**: RMSE overall and in the 2008–09 recession. The sign of a principal component doesn't matter here, because the regression coefficient flips along with it.
# root mean squared error per model
rmse = lambda r: np.sqrt(((r[["AR", "Factor"]].sub(r.actual, axis=0)) ** 2).mean())
# one row per period (.T flips columns into rows)
tab = pd.DataFrame({"2005-2019": rmse(res), "2008-09 recession": rmse(res.loc["2008-01":"2009-06"])}).T
tab["Factor / AR"] = tab["Factor"] / tab["AR"]         # below 1 = factors win
print(tab.round(3))
viz_table(tab, digits=3, highlight="Factor / AR", title="Factors beat the AR benchmark, but only modestly")

#| **Diebold–Mariano test by hand** (squared-error loss, h = 1): the mean loss difference divided by its standard error. R's `dm.test` also applies a small-sample correction, so the numbers differ slightly.
from scipy import stats
dl = (res.actual - res.AR) ** 2 - (res.actual - res.Factor) ** 2   # loss difference each month (AR minus factor)
dm = dl.mean() / (dl.std(ddof=0) / np.sqrt(len(dl)))               # DM statistic: mean / standard error
# two-sided p-value from the standard normal distribution
print({"DM": round(float(dm), 2), "p_value": round(float(2 * (1 - stats.norm.cdf(abs(dm)))), 2)})
