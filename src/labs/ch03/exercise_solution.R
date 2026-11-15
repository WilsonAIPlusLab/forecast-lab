library(forecast)
online <- fred("MRTSSM4541USS", start = 2015)   # U.S. e-commerce sales, $ millions
train  <- window(online, end = c(2022, 12))
test   <- window(online, start = c(2023, 1))

# 1. Forecast the test period with the SEASONAL NAIVE method
f_sn <- snaive(train, h = length(test))

# 2. Compute the test-set MAE by hand: the mean of the absolute errors
mae <- mean(abs(test - f_sn$mean))
mae
