library(forecast)                                       # ARIMA tools: auto.arima(), unit-root helpers
u <- fred("UNRATE", start = 1990, end = c(2019, 12))   # unemployment rate, %, SA

# 1. How many differences does the unemployment rate need? Use the KPSS-based helper.
# Blank: the forecast-package function that counts regular (non-seasonal) differences
d <- ______(u)

# 2. Fit an ARIMA with that d; let auto.arima() choose p and q
fit <- auto.arima(u, d = d, seasonal = FALSE)          # d fixed by you; p and q chosen by AICc
fit                                                    # print the chosen model and its coefficients

# 3. Ljung-Box test on 24 residual autocorrelations.
#    fitdf = the number of estimated ARMA coefficients in the model
# Blank: count the coefficients stored in fit (don't type a fixed number)
lb <- Box.test(residuals(fit), lag = 24, type = "Ljung-Box", fitdf = ______)
lb                                                     # large p-value = residuals look like white noise
