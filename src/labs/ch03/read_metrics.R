#| **Re-create the seasonal naive forecast from the scorecard.** Same data and same split as before: train through December 2022, test from January 2023. The errors `err` are **actual minus forecast**, in millions of dollars. A positive error means the forecast was too low.
library(forecast)                             # Hyndman's forecasting package
retail <- fred("RSXFSN", start = 2010)        # monthly U.S. retail sales, $ millions, not seasonally adjusted
train  <- window(retail, end = c(2022, 12))   # training set: through December 2022
test   <- window(retail, start = c(2023, 1))  # test set: January 2023 onward
f      <- snaive(train, h = length(test))$mean   # $mean = the point forecasts
err    <- test - f                            # forecast errors: actual minus forecast ($ millions)

#| **Bias: which way do we miss?** The mean error (ME) is about +22,000, so on average the forecast is **too low** by about \$22 billion a month. The share of months with a positive error says the same thing in plain words: the forecast was too low in about 4 months out of 5. Why? Nominal retail sales grow every year (more people, higher prices), so "same month last year" lags behind.
mean(err)                                     # ME (bias): + means forecast too low on average
mean(err > 0)                                 # share of months where the forecast was too low
mean(err) / mean(abs(err))                    # ME / MAE near +1 or -1: almost every miss goes the same way

#| **Typical miss vs big misses.** MAE is the size of a typical miss in the data's units. RMSE squares the errors first, so it is always at least as large as MAE. The ratio RMSE ÷ MAE is about 1.26 here: the misses are uneven, and the biggest ones come at the end of the test period. `which.max()` finds the worst month: the last one, September 2026, because seasonal naive keeps repeating 2022's values while sales keep growing, so it falls further behind every year.
mae  <- mean(abs(err))                        # MAE: average size of a miss, $ millions
rmse <- sqrt(mean(err^2))                     # RMSE: root of the average squared miss, $ millions
c(MAE = mae, RMSE = rmse, ratio = rmse / mae) # a ratio of 1 means all misses are the same size
time(err)[which.max(abs(err))]                # date of the largest miss, as a decimal year (2026.667 = Sep 2026)
max(abs(err))                                 # size of that largest miss, $ millions

#| **Plot the errors over time.** A line hugging zero would mean no bias. Here most errors sit above zero: the picture of a forecast that is systematically too low.
viz_lines(time(err), Error = err, zero = TRUE,   # x = date as a decimal year; zero line for reference
          xlab = "year", ylab = "actual − forecast ($ millions)",
          title = "Seasonal naive misses low in most months")

#| **When MAPE misleads: interest rates near zero.** Forecast the federal funds rate one month ahead with the naive rule (next month = this month). In 2004–07 the rate was between 1% and 5.3%; in 2010–15 it sat near 0.1%. The misses in 2010–15 were about **nine times smaller** in percentage points, yet MAPE is **more than twice as large**, because each tiny miss is divided by a tiny actual value.
ff  <- fred("FEDFUNDS", start = 2003)         # effective federal funds rate, %, monthly
eff <- diff(ff)                               # naive one-month-ahead errors: this month minus last month
yff <- window(ff, start = c(2003, 2))         # the actual values those errors are compared with
era <- function(a, b) {                       # MAE and MAPE for the months from year a through year b
  k <- time(eff) >= a & time(eff) < b + 1     # TRUE for months inside the era
  c(`MAE (pct. points)` = mean(abs(eff[k])), `MAPE (%)` = 100 * mean(abs(eff[k] / yff[k])))
}
tab <- rbind(`2004-07 (rate 1-5%)` = era(2004, 2007),     # one row per era
             `2010-15 (rate near 0.1%)` = era(2010, 2015))
tab

#| **Show it as a table.** Same forecasting rule, much smaller misses, but a worse MAPE. That is why MAPE is a poor choice for series near zero, and meaningless for series that can be negative.
viz_table(tab, digits = 3, title = "Near zero, tiny misses produce a big MAPE")
