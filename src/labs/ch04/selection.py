#| **Same vehicle-sales data**, plus the 10-year Treasury yield, which moves almost one-for-one with mortgage rates. `trend` counts months 1, 2, 3, …
import statsmodels.formula.api as smf      # R-style regression formulas
# vehicle sales (mn, SAAR), gas ($/gal), unemployment (%), mortgage rate (%), 10-year Treasury yield (%)
d = pd.concat({"veh": fred("TOTALSA"), "gas": fred("GASREGW", to="month"), "un": fred("UNRATE"),
               "mr": fred("MORTGAGE30US", to="month"), "g10": fred("GS10")}, axis=1, sort=True)
d = d["1993-01":"2026-10"]                 # Jan 1993 to Oct 2026
d["trend"] = np.arange(1, len(d) + 1)      # 1, 2, 3, ... counting months
d = d.dropna()                             # drop months missing any series
d["chip"] = d.index.year.isin([2021, 2022]).astype(int)   # chip-shortage dummy: 1 in 2021-2022, else 0

#| **Six candidate models**, all on the same months.
specs = {"un": "veh ~ un", "gas + un": "veh ~ gas + un", "gas + un + mr": "veh ~ gas + un + mr",   # name -> formula
         "gas + un + mr + chip": "veh ~ gas + un + mr + chip",
         "+ 10-yr yield": "veh ~ gas + un + mr + chip + g10",
         "+ 10-yr yield + trend": "veh ~ gas + un + mr + chip + g10 + trend"}
fits = {k: smf.ols(f, data=d).fit() for k, f in specs.items()}   # dict comprehension: fit every formula

#| **Four of the scores R's `CV()` reports**: leave-one-out CV from the hat values (no refitting needed for OLS), AIC and BIC on R's scale, and adjusted R².
def cv_scores(m):
    n, p = m.nobs, len(m.params)           # sample size, number of coefficients
    e, hat = m.resid, m.get_influence().hat_matrix_diag   # residuals and leverage of each month
    aic = n * np.log(m.ssr / n) + 2 * p + 2   # AIC on R's scale (ssr = sum of squared residuals)
    # CV = mean squared leave-one-out error; BIC = AIC with a log(n) penalty per coefficient
    return {"CV": np.mean((e / (1 - hat))**2), "AIC": aic, "BIC": aic + (p + 1) * (np.log(n) - 2), "AdjR2": m.rsquared_adj}
tab = pd.DataFrame({k: cv_scores(m) for k, m in fits.items()}).T   # one row per model

#| **The honest time split**: refit on data through 2023, score ex-post forecasts for 2024 onward.
train, test = d[:"2023-12"], d["2024-01":]   # training set through Dec 2023; test set from Jan 2024
# for each formula: refit on train, predict test, compute RMSE (list comprehension)
tab["Test RMSE"] = [np.sqrt(np.mean((test.veh - smf.ols(f, data=train).fit().predict(test))**2)) for f in specs.values()]
print(tab.round(3))
viz_table(tab, highlight=["CV", "AIC", "BIC", "Test RMSE"], digits=3,   # green = best in each column
          title="In-sample criteria and the 2024-26 test do not always agree")

#| **Variance inflation factors**, with statsmodels' built-in function. Mortgage rate and 10-year yield are both above 20.
from statsmodels.stats.outliers_influence import variance_inflation_factor
X = fits["+ 10-yr yield"].model.exog       # the model's predictor matrix (column 0 = intercept)
names = fits["+ 10-yr yield"].model.exog_names   # column names
# VIF for every column except the intercept (j starts at 1); above about 10 is a warning sign
print({names[j]: round(float(variance_inflation_factor(X, j)), 1) for j in range(1, X.shape[1])})

#| **Collinearity changes the slopes, not the fitted values.**
print("mortgage slope:", round(fits["gas + un + mr + chip"].params["mr"], 3), "->", round(fits["+ 10-yr yield"].params["mr"], 3))
# correlation near 1 = the two models make almost the same predictions
print("correlation of fitted values:", round(np.corrcoef(fits["gas + un + mr + chip"].fittedvalues, fits["+ 10-yr yield"].fittedvalues)[0, 1], 4))
