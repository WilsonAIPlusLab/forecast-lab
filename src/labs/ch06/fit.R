#| **Monthly core PCE inflation**, annualized (% per year), January 2000 onward. This is the series whose ACF you just read.
library(forecast)                             # Arima(), auto.arima(), forecast()
pce  <- fred("PCEPILFE", start = c(2000, 1))  # core PCE price index, monthly
infl <- 1200 * diff(log(pce))                 # annualized monthly inflation, % per year

#| **Model 1, by hand: ARIMA(0,1,1).** The ACF of *changes* in inflation had one spike at lag 1, so we difference once (d = 1) and add one MA term (q = 1). `Arima()` estimates θ by maximum likelihood.
#| Read the result like this: θ ≈ −0.82 means the forecast is an exponentially weighted average of past inflation with weight 1 + θ ≈ 0.18 on the newest month. That is simple exponential smoothing from Chapter 6, in ARIMA clothing.
fit_ima <- Arima(infl, order = c(0, 1, 1))    # order = c(p, d, q): no AR, one difference, one MA term
fit_ima                                       # print theta (ma1), its s.e., and AICc

#| **Model 2, by hand: a stationary ARMA(1,1) with a mean.** Here we bet that inflation does *not* have a unit root (d = 0). The AR coefficient φ measures persistence, and its **half-life**, log(0.5)/log(φ), says how many months it takes for half of a surprise to fade.
fit_arma <- Arima(infl, order = c(1, 0, 1), include.mean = TRUE)   # no differencing; estimate a long-run mean
fit_arma
# pull out phi and the mean ("intercept"); unname() drops labels for a tidy printout
c(phi = unname(coef(fit_arma)["ar1"]), mean = unname(coef(fit_arma)["intercept"]),
  half_life_months = log(0.5) / log(unname(coef(fit_arma)["ar1"])))   # months for half a shock to fade

#| **Let `auto.arima()` decide.** It first picks d with repeated KPSS tests (`ndiffs()`), then searches p and q by AICc. Here it lands on exactly the model we built by hand. Note that ADF would have chosen d = 0 instead: the two tests disagree about inflation.
#| Never compare AICc across models with *different d*: differencing changes the data the likelihood is computed on, so the numbers are not on the same scale.
fit_auto <- auto.arima(infl, seasonal = FALSE)   # automatic search over d, p and q (no seasonal terms)
fit_auto
c(ndiffs_kpss = ndiffs(infl), ndiffs_adf = ndiffs(infl, test = "adf"))   # d chosen by KPSS vs by ADF

#| **Residual diagnostics.** If the model has captured the dynamics, the residuals should be white noise. `checkresiduals()` runs the **Ljung–Box test** on the first 24 residual autocorrelations. Its null is "no autocorrelation left", so a *large* p-value is good news.
checkresiduals(fit_auto, plot = FALSE)        # prints the Ljung-Box test only (no plot)
viz_acf(residuals(fit_auto), lag.max = 36, title = "Residual ACF: 1 bar in 36 outside the band, about what chance alone produces")

#| **Same data, two stories about the future.** The IMA model (d = 1) says inflation stays where it is now, forever. The ARMA model (d = 0) says it drifts back to its 2000–2026 average of about 2.2%, slowly. The data fit both about equally well; the d decision drives the long-run forecast.
fc_ima  <- forecast(fit_ima,  h = 24)         # forecast 24 months ahead with the unit-root model
fc_arma <- forecast(fit_arma, h = 24)         # same horizon with the mean-reverting model
viz_compare(history = window(infl, start = 2019), `ARIMA(0,1,1): no mean reversion` = fc_ima,   # window() keeps 2019 onward
            `ARMA(1,1): slow return to 2.2%` = fc_arma,
            title = "Unit root or not? The answer decides where inflation is heading")
