#| **Data.** Monthly change in payrolls (thousands) and monthly % change in claims, 1990 to 2019.
import statsmodels.api as sm
from statsmodels.stats.diagnostic import acorr_breusch_godfrey
from statsmodels.tsa.arima.model import ARIMA
claims = fred("ICSA", to="month")
jobs = fred("PAYEMS")
dj = jobs.diff()                          # jobs added this month, thousands
dcl = 100 * np.log(claims).diff()         # % change in claims from last month
d = pd.DataFrame({"dj": dj, "dcl": dcl}).dropna()

#| **Static regression and its residuals.** Breusch–Godfrey with 12 lags: a tiny p-value means autocorrelated errors, so the usual OLS standard errors are too small.
s = d["1990-01":"2019-12"]
static = sm.OLS(s["dj"], sm.add_constant(s["dcl"])).fit()
print("BG p-value:", acorr_breusch_godfrey(static, nlags=12)[1])
from statsmodels.tsa.stattools import acf
print("residual autocorrelation, lags 1-3:", acf(static.resid, nlags=3)[1:].round(2))

#| **OLS vs Newey–West standard errors.** `cov_type="HAC"` with 6 lags and no small-sample correction matches R's `NeweyWest(lag = 6, prewhite = FALSE)`.
nw = sm.OLS(s["dj"], sm.add_constant(s["dcl"])).fit(cov_type="HAC", cov_kwds={"maxlags": 6, "use_correction": False})
print(pd.DataFrame({"coef": static.params, "OLS se": static.bse, "Newey-West se": nw.bse}).round(2))

#| **ADL(2, 3)**: build the lags by hand with `shift()`, then fit on 1990 to 2019.
X = pd.DataFrame({"dj_1": d["dj"].shift(1), "dj_2": d["dj"].shift(2),
                  **{f"dcl_{k}": d["dcl"].shift(k) for k in range(4)}})
D = pd.concat([d["dj"], X], axis=1)["1990-01":"2019-12"]
adl = sm.OLS(D["dj"], sm.add_constant(D.drop(columns="dj"))).fit(cov_type="HAC", cov_kwds={"maxlags": 6, "use_correction": False})
print(adl.summary().tables[1])

#| **Dynamic multipliers** from feeding a one-time 1% rise in claims through the fitted equation.
phi = adl.params[["dj_1", "dj_2"]].values; beta = adl.params[[f"dcl_{k}" for k in range(4)]].values
H = 24; irf = np.zeros(H + 1)
for h in range(H + 1):
    irf[h] = (beta[h] if h <= 3 else 0) + (phi[0] * irf[h - 1] if h >= 1 else 0) + (phi[1] * irf[h - 2] if h >= 2 else 0)
long_run = beta.sum() / (1 - phi.sum())
print(pd.Series({"impact": beta[0], "after_12_months": irf[:13].sum(), "long_run": long_run}).round(1))

#| **The response to a 10% jump in claims.**
viz_custom("ch07-multipliers", h=list(range(H + 1)), value=(10 * irf).tolist(), cumulative=np.cumsum(10 * irf).tolist(),
           ylab="thousands of jobs", title="A 10% jump in claims costs jobs for months, not just once",
           source="FRED (ICSA, PAYEMS); ADL(2,3), 1990–2019")

#| **Regression with ARIMA(2,0,2) errors**, the order R's `auto.arima()` picks. statsmodels has no `auto.arima`, so we give the order directly. Estimates differ slightly from R because the optimizers differ.
arx = ARIMA(s["dj"].values, exog=s["dcl"].values, order=(2, 0, 2)).fit()
print(pd.DataFrame({"coef": arx.params, "se": arx.bse}, index=arx.param_names).round(3))
