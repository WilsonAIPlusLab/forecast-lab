library(forecast)                             # Hyndman's forecasting package
online <- fred("MRTSSM4541USS", start = 2015)   # U.S. e-commerce sales, $ millions
train  <- window(online, end = c(2022, 12))   # training set: everything up to December 2022
test   <- window(online, start = c(2023, 1))  # test set: January 2023 onward

# 1. Forecast the test period with the SEASONAL NAIVE method
f_sn <- ______(train, h = length(test))       # blank: the forecast-package function for this method

# 2. Compute the test-set MAE by hand: the mean of the absolute errors
mae <- mean(abs(______ - f_sn$mean))          # blank: what actually happened (error = actual - forecast)
mae
