library(forecast)                             # Hyndman's forecasting package
retail <- fred("RSXFSN", start = 2010)        # monthly U.S. retail sales, $ millions, NSA
train  <- window(retail, end = c(2022, 12))   # training set: through December 2022
test   <- window(retail, start = c(2023, 1))  # test set: January 2023 onward
f_sn   <- snaive(train, h = length(test))$mean   # seasonal naive forecasts
f_nv   <- naive(train, h = length(test))$mean    # naive forecasts

# Business cost per month. Each $1 million of UNDER-forecast (empty shelves, lost sales)
# costs 4 cost units; each $1 million of OVER-forecast (leftover stock) costs 1 unit.
biz_cost <- function(actual, fc) {
  e <- actual - fc                            # error: + means the forecast was too low
  mean(ifelse(e > 0, 4 * e, -e))              # under: 4 units per $1M; over: -e is the positive size of the miss
}

costs <- c(`Seasonal naive` = biz_cost(test, f_sn), Naive = biz_cost(test, f_nv))
maes  <- c(`Seasonal naive` = mean(abs(test - f_sn)), Naive = mean(abs(test - f_nv)))
rbind(MAE = maes, Cost = costs)               # MAE picks seasonal naive; the 4-to-1 cost picks naive
