#| **Monthly core PCE inflation**, annualized (% per year), January 2000 onward.
import warnings
from statsmodels.tsa.arima.model import ARIMA
from statsmodels.stats.diagnostic import acorr_ljungbox
pce = fred("PCEPILFE", start=2000)
infl = (1200 * np.log(pce).diff()).dropna()

#| **Model 1 by hand: ARIMA(0,1,1).** θ ≈ −0.82, so the forecast is an exponentially weighted average of past inflation with weight 1 + θ ≈ 0.18 on the newest month: simple exponential smoothing in ARIMA clothing.
fit_ima = ARIMA(infl, order=(0, 1, 1)).fit()
print(fit_ima.params.round(3))

#| **Model 2 by hand: stationary ARMA(1,1) with a mean.** φ measures persistence; its half-life is log(0.5)/log(φ) months.
fit_arma = ARIMA(infl, order=(1, 0, 1), trend="c").fit()
phi = float(fit_arma.params["ar.L1"])
print(fit_arma.params.round(3))
print({"phi": round(phi, 3), "mean": round(float(fit_arma.params["const"]), 2), "half_life_months": round(float(np.log(0.5) / np.log(phi)), 1)})

#| **A mini `auto.arima()`.** statsmodels has no automatic ARIMA, so we fix d = 1 (what KPSS-based `ndiffs()` chose in R) and search p, q ∈ {0, 1, 2} by AIC. As in R, ARIMA(0,1,1) wins or comes very close.
aic = {}
with warnings.catch_warnings():
    warnings.simplefilter("ignore")
    for p in range(3):
        for q in range(3):
            aic[(p, 1, q)] = ARIMA(infl, order=(p, 1, q)).fit().aic
print(pd.Series(aic).sort_values().head(4).round(1))

#| **Ljung–Box on the residuals** (24 lags, one estimated parameter). A large p-value means no autocorrelation is left.
resid = fit_ima.resid.iloc[1:]
print(acorr_ljungbox(resid, lags=[24], model_df=1))
viz_acf(resid, lag_max=36, title="Residual ACF: almost nothing left to model")

#| **Two stories about the future**: flat at today's level (d = 1) versus a slow return to the long-run mean (d = 0).
viz_compare(history=infl["2019":], **{"ARIMA(0,1,1): no mean reversion": fit_ima.forecast(24),
            "ARMA(1,1): slow return to 2.2%": fit_arma.forecast(24)},
            title="Unit root or not? The answer decides where inflation is heading")
