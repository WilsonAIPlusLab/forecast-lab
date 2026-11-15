#| **Monthly core PCE inflation**, annualized (% per year), January 2000 onward.
import warnings                                          # to silence noisy optimizer warnings below
from statsmodels.tsa.arima.model import ARIMA            # statsmodels' ARIMA estimator
from statsmodels.stats.diagnostic import acorr_ljungbox  # Ljung-Box test for leftover autocorrelation
pce = fred("PCEPILFE", start=2000)                       # core PCE price index, monthly
infl = (1200 * np.log(pce).diff()).dropna()              # annualized monthly inflation, % per year

#| **Model 1 by hand: ARIMA(0,1,1).** θ ≈ −0.82, so the forecast is an exponentially weighted average of past inflation with weight 1 + θ ≈ 0.18 on the newest month: simple exponential smoothing in ARIMA clothing.
fit_ima = ARIMA(infl, order=(0, 1, 1)).fit()   # order = (p, d, q): no AR, one difference, one MA term
print(fit_ima.params.round(3))                 # ma.L1 is theta; sigma2 is the shock variance

#| **Model 2 by hand: stationary ARMA(1,1) with a mean.** φ measures persistence; its half-life is log(0.5)/log(φ) months.
fit_arma = ARIMA(infl, order=(1, 0, 1), trend="c").fit()   # no differencing; trend="c" estimates a constant mean
phi = float(fit_arma.params["ar.L1"])                      # the AR(1) coefficient
print(fit_arma.params.round(3))
# phi, the long-run mean ("const"), and the half-life in months
print({"phi": round(phi, 3), "mean": round(float(fit_arma.params["const"]), 2), "half_life_months": round(float(np.log(0.5) / np.log(phi)), 1)})

#| **A mini `auto.arima()`.** statsmodels has no automatic ARIMA, so we fix d = 1 (what KPSS-based `ndiffs()` chose in R) and search p, q ∈ {0, 1, 2} by AIC. As in R, ARIMA(0,1,1) wins or comes very close.
aic = {}                                       # dictionary: (p, d, q) -> AIC
with warnings.catch_warnings():                # hide convergence warnings inside this block only
    warnings.simplefilter("ignore")
    for p in range(3):                         # p = 0, 1, 2
        for q in range(3):                     # q = 0, 1, 2
            aic[(p, 1, q)] = ARIMA(infl, order=(p, 1, q)).fit().aic
print(pd.Series(aic).sort_values().head(4).round(1))   # four best models, lowest AIC first

#| **Ljung–Box on the residuals** (24 lags, one estimated parameter). A large p-value means no autocorrelation is left.
resid = fit_ima.resid.iloc[1:]                 # .iloc[1:] drops the first residual (no prior month to difference)
print(acorr_ljungbox(resid, lags=[24], model_df=1))   # model_df = estimated ARMA coefficients (R's fitdf)
viz_acf(resid, lag_max=36, title="Residual ACF: almost nothing left to model")

#| **Two stories about the future**: flat at today's level (d = 1) versus a slow return to the long-run mean (d = 0).
# **{...} passes dictionary entries as named arguments, so labels may contain spaces
viz_compare(history=infl["2019":], **{"ARIMA(0,1,1): no mean reversion": fit_ima.forecast(24),
            "ARMA(1,1): slow return to 2.2%": fit_arma.forecast(24)},   # 24-month-ahead forecasts
            title="Unit root or not? The answer decides where inflation is heading")
