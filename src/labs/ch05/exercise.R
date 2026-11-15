library(forecast)                          # forecasting functions
clothing <- fred("MRTSSM448USN", start = 2015)   # clothing stores, $ millions, NSA
train <- window(clothing, end = c(2025, 8))      # training set: through August 2025
test  <- window(clothing, start = c(2025, 9))    # test set: September 2025 onward

# 1. Let R choose the best exponential smoothing model by AICc
# blank: the function that searches over Error, Trend and Season types
fit <- ______(train)
fit$method                                 # the name of the model it chose

# 2. Forecast every month of the test period
# blank: the horizon, i.e. how many months the test set covers
fc <- forecast(fit, h = ______)

# 3. Pull the test-set MASE out of accuracy()
# blank: the column name of the scaled error metric (spelling and case matter)
mase <- accuracy(fc, test)["Test set", "______"]
mase                                       # below 1 = better than seasonal naive's in-sample error
