library(forecast)                             # Hyndman's forecasting package
online <- fred("MRTSSM4541USS", start = 2015) # U.S. e-commerce sales, $ millions, seasonally adjusted
train  <- window(online, end = c(2022, 12))   # training set: through December 2022
test   <- window(online, start = c(2023, 1))  # test set: January 2023 onward
h      <- length(test)                        # number of test months

f_level <- rwf(train, h = h, drift = TRUE)$mean        # drift on levels: same $ change every month
f_log   <- rwf(log(train), h = h, drift = TRUE)$mean   # drift on logs: same % growth every month (in log units)
f_back  <- ______(f_log)                      # blank: undo the log, so the forecast is in $ millions again

# Score BOTH forecasts in the original units, $ millions
mae_level <- mean(abs(test - f_level))
mae_log   <- mean(abs(test - ______))         # blank: the log-model forecast, in $ millions
c(level = mae_level, log = mae_log)           # same units, so now the two numbers can be compared
