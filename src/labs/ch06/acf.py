#| **Core PCE prices** (index 2017 = 100, monthly, SA), in logs so that a difference is a percentage change.
pce = fred("PCEPILFE", start=2000)    # core PCE price index, monthly pandas Series from Jan 2000
lp = np.log(pce)                      # log price level: differences become % changes

#| **ACF of the trending level**: everything near 1, fading slowly. The signature of a unit root.
viz_acf(lp, lag_max=36, title="Log price level: autocorrelations fade very slowly, a sign of a unit root")   # ACF up to 3 years

#| **One difference turns prices into inflation**, annualized to percent per year.
infl = (1200 * lp.diff()).dropna()    # .diff() = this month minus last; x 100 for %, x 12 to annualize; drop first NaN
viz_ts(infl, title="Monthly core PCE inflation, annualized", ylab="% per year (annualized m/m)")

#| **ACF and PACF of inflation**: slow ACF decay, a few short PACF spikes. Persistent, maybe stationary, maybe not. (statsmodels' default PACF estimator differs slightly from R's, so the PACF bars can differ in the second decimal.)
viz_acf(infl, lag_max=36, title="Inflation ACF: slow decay, so shocks to inflation linger")
viz_acf(infl, lag_max=36, kind="pacf", title="Inflation PACF: a few short-lag spikes, then noise")   # partial ACF

#| **Difference once more**: one negative spike at lag 1 (about −0.45), then nothing. The MA(1) signature, so inflation looks like ARIMA(0,1,1).
dinfl = infl.diff().dropna()          # change in inflation from one month to the next
viz_acf(dinfl, lag_max=36, title="Change in inflation: one negative spike at lag 1, the MA(1) signature")
from statsmodels.tsa.stattools import acf
print(acf(dinfl, nlags=3)[1:].round(3))   # autocorrelations at lags 1-3 (element 0 is lag 0, always 1)

#| **Seasonal data need a seasonal difference.** statsmodels has no `nsdiffs()`, but the ACF tells the story: log retail sales (NSA) still have huge, slowly fading spikes at lags 12, 24, 36 after a regular difference (about 0.87, 0.73, 0.64). Add a lag-12 difference and that slow seasonal decay disappears. What is left (a big negative spike at lag 1, a few smaller ones) is short-lived structure for the AR and MA terms to model.
retail = np.log(fred("RSXFSN", start=2010, end="2019-12-01"))   # log retail sales (NSA), 2010-2019
# regular difference only: seasonal spikes remain
viz_acf(retail.diff().dropna(), lag_max=36, title="After one regular difference, seasonal spikes at 12, 24, 36 remain")
# .diff(12) = lag-12 (seasonal) difference, then a regular .diff(); method chaining applies them in order
viz_acf(retail.diff(12).diff().dropna(), lag_max=36, title="After a seasonal and a regular difference, the slow seasonal decay is gone")
