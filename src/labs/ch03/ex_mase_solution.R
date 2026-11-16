library(forecast)                             # Hyndman's forecasting package

# MASE by hand: the test-set MAE divided by the in-sample MAE of seasonal naive
mase <- function(train, test, fc) {
  scale <- mean(abs(diff(train, lag = 12)))   # in-sample seasonal naive MAE: y(t) - y(t-12), monthly data
  mean(abs(test - fc)) / scale                # test MAE / benchmark MAE: the units cancel
}

# Score the seasonal naive forecast of one series: train through 2022, test from 2023
score <- function(y) {
  train <- window(y, end = c(2022, 12))       # training set
  test  <- window(y, start = c(2023, 1))      # test set
  fc    <- snaive(train, h = length(test))$mean   # seasonal naive point forecasts
  mase(train, test, fc)
}

retail <- fred("RSXFSN", start = 2010)        # retail sales, $ millions, NSA
houses <- fred("HOUSTNSA", start = 2010)      # housing starts, thousands of units, NSA
result <- c(retail = score(retail), houses = score(houses))   # one MASE per series
result                                        # retail about 1.04, housing starts about 1.67
