library(forecast)                             # Hyndman's forecasting package
online <- fred("MRTSSM4541USS", start = 2015) # U.S. e-commerce sales, $ millions, seasonally adjusted
train  <- window(online, end = c(2022, 12))   # training set: through December 2022
test   <- window(online, start = c(2023, 1))  # test set: January 2023 onward
h      <- length(test)                        # number of test months

f_level <- rwf(train, h = h, drift = TRUE)$mean        # drift on levels: same $ change every month
f_log   <- rwf(log(train), h = h, drift = TRUE)$mean   # drift on logs: same % growth every month (in log units)
f_back  <- exp(f_log)                         # exp() undoes log(): back to $ millions

# Score BOTH forecasts in the original units, $ millions
mae_level <- mean(abs(test - f_level))
mae_log   <- mean(abs(test - f_back))         # compare actual $ with back-transformed $
c(level = mae_level, log = mae_log)           # about 1,958 vs 13,397: the straight line wins
