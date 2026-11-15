library(forecast)                             # Hyndman's forecasting package
online <- fred("MRTSSM4541USS", start = 2015)   # U.S. e-commerce sales, $ millions
train  <- window(online, end = c(2022, 12))   # training set: everything up to December 2022
test   <- window(online, start = c(2023, 1))  # test set: January 2023 onward

# 1. Forecast the test period with the SEASONAL NAIVE method
f_sn <- snaive(train, h = length(test))       # forecast = same month one year earlier

# 2. Compute the test-set MAE by hand: the mean of the absolute errors
mae <- mean(abs(test - f_sn$mean))            # f_sn$mean = the point forecasts; error = actual - forecast
mae
