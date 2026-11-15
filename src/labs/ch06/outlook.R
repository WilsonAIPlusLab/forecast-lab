#| **Model the price level, report inflation.** We fit models to *log* core PCE prices (monthly, SA, 2000 onward). Any forecast of the log level converts exactly into a forecast of 12-month inflation, intervals included.
library(forecast)                                    # Arima(), auto.arima(), ets(), forecast()
pce <- fred("PCEPILFE", start = c(2000, 1))          # core PCE price index, monthly
lp  <- log(pce)                                      # log price level: the series we model
yoy <- 100 * (pce / stats::lag(pce, -12) - 1)       # 12-month inflation, %

#| **Three contenders, plus a benchmark.**
#| - `auto.arima()` picks **ARIMA(0,2,1)**: twice-differenced log prices, i.e. the IMA model for inflation from the previous lab.
#| - **ARIMA(1,1,1) with drift**: inflation is stationary and drifts back to its mean.
#| - **ETS(A,A,N)**: Holt's linear trend method from Chapter 6, applied to log prices.
#| - The benchmark: *inflation over the next 12 months will equal inflation over the last 12* (Atkeson & Ohanian, 2001).
fit_auto <- auto.arima(lp)                           # automatic model on log prices (used for the fan chart)
fit_auto
# Each model is a function(y, h) that returns h forecasts of log prices made from history y
models <- list(
  # benchmark: extend the last 12 months' average monthly log change in a straight line
  `Last 12 months (benchmark)` = function(y, h) { k <- length(y); y[k] + (1:h) * (y[k] - y[k - 12]) / 12 },
  `ARIMA(0,2,1)`         = function(y, h) forecast(Arima(y, order = c(0, 2, 1)), h = h)$mean,   # $mean = point forecasts
  `ARIMA(1,1,1) + drift` = function(y, h) forecast(Arima(y, order = c(1, 1, 1), include.drift = TRUE), h = h)$mean,
  `ETS(A,A,N)`           = function(y, h) forecast(ets(y, model = "AAN", damped = FALSE), h = h)$mean)   # Holt, undamped

#| **Rolling-origin evaluation** (Chapter 3), scored on what we actually care about: 12-month inflation. We stand at 31 origins (every June and December from mid-2010 to mid-2025), refit every model on the data up to that date, forecast 12 months ahead and record the error in percentage points. This is `tsCV()` with a six-month step, to keep it fast in the browser.
tt <- time(lp); n <- length(lp)                      # tt = decimal dates (2010.0 = Jan 2010); n = number of months
# origins: positions of every June and December from 2010 that still leave 12 months to check
# (cycle() gives the month number 1-12; %in% tests membership in a set)
origins <- which(tt >= 2010 & tt <= tt[n - 12] & cycle(lp) %in% c(6, 12))
# For model m: one row per origin, one column per horizon (1-12) of 12-month-inflation errors.
# sapply() loops over origins and collects results; t() flips them to rows = origins.
yoy_err <- function(m) t(sapply(origins, function(o) {
  f <- as.numeric(m(window(lp, end = tt[o]), 12)); i <- o + 1:12   # refit on data up to origin; i = the 12 target months
  100 * (exp(lp[i] - lp[i - 12]) - 1) - 100 * (exp(f - lp[i - 12]) - 1)   # actual minus forecast
}))
E <- lapply(models, yoy_err)                         # error matrix for every model (lapply returns a list)
length(origins)                                      # number of forecast origins (31)

#| **The scorecard.** All three models beat the benchmark, but not by much, and ARIMA(0,2,1) and ETS(A,A,N) finish almost level. That is no accident: Holt's method is mathematically equivalent to an ARIMA(0,2,2), a close cousin of our ARIMA(0,2,1). A positive ME means inflation came in *higher* than forecast on average, mostly because of 2021–22.
# Column 12 of each error matrix = the 12-months-ahead error; [rows, cols] indexing picks pre-/post-2020 origins
score <- t(sapply(E, function(e) c(MAE = mean(abs(e[, 12])), RMSE = sqrt(mean(e[, 12]^2)), ME = mean(e[, 12]),
  `MAE before 2020` = mean(abs(e[tt[origins] < 2020, 12])), `MAE 2020 on` = mean(abs(e[tt[origins] >= 2020, 12])))))
viz_table(score, highlight = c("MAE", "RMSE"), digits = 2,   # green = lowest error in each column
          title = "12-month-ahead inflation errors (pp): ARIMA and ETS tie, both edge out the benchmark")

#| **Error by horizon.** One month ahead every method misses by about 0.1 point, because 11 of the 12 months in the year-over-year rate are already known. By month 12 the typical miss is about 0.6 point.
# colMeans(abs(...)) = mean absolute error at each horizon 1-12; E[[k]] is the k-th model's matrix
viz_lines(1:12, `Last 12 months (benchmark)` = colMeans(abs(E[[1]])), `ARIMA(0,2,1)` = colMeans(abs(E[[2]])),
          `ARIMA(1,1,1) + drift` = colMeans(abs(E[[3]])), `ETS(A,A,N)` = colMeans(abs(E[[4]])),
          xlab = "months ahead", ylab = "MAE (percentage points)", zero = TRUE,
          title = "Errors grow with the horizon, and the models stay bunched together")

#| **The deliverable: a 12-month inflation fan chart.** We forecast log prices with the `auto.arima()` model, then convert each forecast and each interval bound to 12-month inflation. The base month of each rate (12 months earlier) is already observed, so this conversion is exact.
fc <- forecast(fit_auto, h = 12, level = c(80, 95))  # 12-month forecast of log prices with 80% and 95% intervals
base <- as.numeric(tail(lp, 12))                     # last 12 observed log prices: the base month of each rate
# convert forecast log prices to 12-month inflation (%), as a monthly ts aligned with the forecast
to_yoy <- function(v) ts(100 * (exp(as.numeric(v) - base) - 1), start = start(fc$mean), frequency = 12)
# bundle history, mean and interval bounds (column 1 = 80%, column 2 = 95%) in the format viz_forecast() expects
outlook <- list(method = "ARIMA(0,2,1) on log core PCE", x = window(yoy, start = 2016), mean = to_yoy(fc$mean),
                lower = cbind(`80%` = to_yoy(fc$lower[, 1]), `95%` = to_yoy(fc$lower[, 2])),
                upper = cbind(`80%` = to_yoy(fc$upper[, 1]), `95%` = to_yoy(fc$upper[, 2])))
viz_forecast(outlook, ylab = "% change from a year earlier",
             title = "Core PCE inflation is expected to stay near 3% over the next 12 months",
             subtitle = "ARIMA(0,2,1) on log core PCE prices; 80% and 95% prediction intervals")

#| **The numbers for your memo.** The point forecast 12 months out, its 80% interval, and what the mean-reverting model says instead. The gap between the last two numbers is the price of the unit-root judgment call.
fc_mr <- forecast(Arima(lp, order = c(1, 1, 1), include.drift = TRUE), h = 12)   # mean-reverting alternative
h12 <- 12                                            # the 12-months-ahead position
viz_kpi(`Latest 12-month rate` = sprintf("%.1f%%", tail(yoy, 1)),   # sprintf: format with 1 decimal and a % sign
        `Forecast, 12 months out` = sprintf("%.1f%%", outlook$mean[h12]),
        `80% interval` = sprintf("%.1f%% to %.1f%%", outlook$lower[h12, 1], outlook$upper[h12, 1]),
        `Mean-reverting model` = sprintf("%.1f%%", 100 * (exp(fc_mr$mean[h12] - base[h12]) - 1)),
        title = "Core PCE inflation outlook")
