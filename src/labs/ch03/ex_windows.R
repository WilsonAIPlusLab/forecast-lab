library(forecast)                             # Hyndman's forecasting package
unrate <- fred("UNRATE", start = 2005)        # unemployment rate, %, seasonally adjusted

# Score naive and drift on ONE test year: train through December of `yr`, test on the next 12 months
score_year <- function(yr) {
  train <- window(unrate, end = c(yr, 12))    # everything up to December of yr
  nxt   <- ______                             # blank: the test year, right after the training data ends
  test  <- window(unrate, start = c(nxt, 1), end = c(nxt, 12))   # January to December of the test year
  c(naive = mean(abs(test - naive(train, h = 12)$mean)),         # MAE of naive, percentage points
    drift = mean(abs(test - rwf(train, h = 12, drift = TRUE)$mean)))   # MAE of drift
}

res <- t(sapply(2010:2018, score_year))       # sapply runs score_year for each year; t() = one row per year
rownames(res) <- 2011:2019                    # label each row by its test year
round(res, 2)
wins_naive <- sum(res[, "naive"] ______ res[, "drift"])   # blank: TRUE when naive's MAE is smaller (TRUE counts as 1)
wins_naive                                    # number of test years naive wins, out of 9
colMeans(res)                                 # average MAE over all 9 test years
