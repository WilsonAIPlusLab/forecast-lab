library(forecast)                          # forecasting functions
clothing <- fred("MRTSSM448USN", start = 2015)   # clothing stores, $ millions, NSA
train <- window(clothing, end = c(2025, 8))      # training set: through August 2025
test  <- window(clothing, start = c(2025, 9))    # test set: September 2025 onward

# 1. Let R choose the best exponential smoothing model by AICc
fit <- ets(train)                          # automatic ETS selection by AICc
fit$method                                 # the name of the model it chose

# 2. Forecast every month of the test period
fc <- forecast(fit, h = length(test))      # horizon = number of test months

# 3. Pull the test-set MASE out of accuracy()
mase <- accuracy(fc, test)["Test set", "MASE"]   # [row, column] picks one number
mase                                       # below 1 = better than seasonal naive's in-sample error
