library(forecast)                             # Hyndman's forecasting package
unrate <- fred("UNRATE", start = 2005)        # unemployment rate, %, seasonally adjusted

# Score naive and drift on ONE test year: train through December of `yr`, test on the next 12 months
score_year <- function(yr) {
  train <- window(unrate, end = c(yr, 12))    # everything up to December of yr
  nxt   <- yr + 1                              # test year = the year right after training ends
  test  <- window(unrate, start = c(nxt, 1), end = c(nxt, 12))   # January to December of the test year
  c(naive = mean(abs(test - naive(train, h = 12)$mean)),         # MAE of naive, percentage points
    drift = mean(abs(test - rwf(train, h = 12, drift = TRUE)$mean)))   # MAE of drift
}

res <- t(sapply(2010:2018, score_year))       # sapply runs score_year for each year; t() = one row per year
rownames(res) <- 2011:2019                    # label each row by its test year
round(res, 2)
wins_naive <- sum(res[, "naive"] < res[, "drift"])   # TRUE (= 1) when naive misses less
wins_naive                                    # naive wins 5 of the 9 years, drift wins 4
colMeans(res)                                 # averaged over 9 years, naive misses less (0.35 vs 0.44)
