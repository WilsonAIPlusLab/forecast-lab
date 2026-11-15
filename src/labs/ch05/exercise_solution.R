library(forecast)
clothing <- fred("MRTSSM448USN", start = 2015)   # clothing stores, $ millions, NSA
train <- window(clothing, end = c(2025, 8))
test  <- window(clothing, start = c(2025, 9))

# 1. Let R choose the best exponential smoothing model by AICc
fit <- ets(train)
fit$method

# 2. Forecast every month of the test period
fc <- forecast(fit, h = length(test))

# 3. Pull the test-set MASE out of accuracy()
mase <- accuracy(fc, test)["Test set", "MASE"]
mase
