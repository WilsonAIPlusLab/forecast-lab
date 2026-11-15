#| **The configuration.** This rebuilds the Studio's default view: U.S. retail sales excluding food services (FRED `RSXFSN`, **not seasonally adjusted**), divided by 1,000 to turn $ millions into **$ billions**, January 2010 through the latest month, forecast 12 months ahead. We evaluate at **12 forecast origins**, one every four months over the last four years (the Studio uses all 48 months; re-fitting ARIMA 48 times would be too slow in a browser).
library(forecast)
y <- fred("RSXFSN", start = 2010) / 1000
h <- 12
origins <- seq(length(y) - 48, length(y) - 4, by = 4)

#| **Choose the model forms using only data before the first origin.** `ets()` picks the exponential-smoothing form by AICc ([Chapter 6](/chapters/exponential-smoothing/)); we limit it to multiplicative errors and seasonality (`"MZM"`) to keep it quick. `auto.arima()` picks the ARIMA orders ([Chapter 7](/chapters/arima/)). Because `pre` ends at the first origin, nothing we evaluate later has been seen during model selection.
pre <- window(y, end = time(y)[origins[1]])
e_form <- ets(pre, model = "MZM")
a_form <- auto.arima(pre, stepwise = TRUE, approximation = TRUE)
c(ETS = e_form$method, ARIMA = as.character(a_form))

#| **Four forecasting functions.** Each takes the data up to an origin, **re-estimates** its parameters on that data alone, and returns `h` forecasts. The combination is the plain average of ETS and ARIMA ([Chapter 11](/chapters/uncertainty/)).
f <- list(`Seasonal naive` = function(x) snaive(x, h = h)$mean,
          Drift = function(x) rwf(x, h = h, drift = TRUE)$mean,
          ETS = function(x) forecast(ets(x, model = paste(e_form$components[1:3], collapse = ""),
                                         damped = e_form$components[4] == "TRUE"), h = h)$mean,
          ARIMA = function(x) forecast(Arima(x, order = arimaorder(a_form)[1:3], seasonal = arimaorder(a_form)[4:6], include.drift = "drift" %in% names(coef(a_form))), h = h)$mean)

#| **Rolling-origin evaluation** ([Chapter 3](/chapters/benchmarks/)). At each origin `o`, every method is re-fitted on `y[1:o]` and its forecasts are compared with the 12 values that followed: one row of errors per origin, one column per horizon. Values past the end of the data are `NA` and are skipped. The combination's errors are the average of the ETS and ARIMA errors.
errs <- lapply(f, function(fun) t(sapply(origins, function(o) y[o + 1:h] - as.numeric(fun(window(y, end = time(y)[o]))))))
errs$Combination <- (errs$ETS + errs$ARIMA) / 2
fc <- lapply(f, function(fun) fun(y))
fc$Combination <- (fc$ETS + fc$ARIMA) / 2

#| **The scorecard.** `mae_h` holds the MAE at each horizon (rows) for each method (columns). The scorecard averages over horizons 1 to 12, like the Studio. MASE divides by the in-sample seasonal naive MAE, and Bias is the mean error (positive = forecasts too low).
mae_h <- sapply(errs, function(m) colMeans(abs(m), na.rm = TRUE))
score <- data.frame(MAE = colMeans(mae_h),
                    RMSE = sapply(errs, function(m) mean(sqrt(colMeans(m^2, na.rm = TRUE)))),
                    MASE = colMeans(mae_h) / mean(abs(diff(y, lag = 12))),
                    Bias = sapply(errs, function(m) mean(m, na.rm = TRUE)))
best <- rownames(score)[which.min(score$MAE)]
viz_table(score, highlight = c("MAE", "RMSE", "MASE"), digits = 2,
          title = sprintf("%s wins on 12 rolling origins ($ billions)", best))
viz_lines(1:h, `Seasonal naive` = mae_h[, "Seasonal naive"], ETS = mae_h[, "ETS"], ARIMA = mae_h[, "ARIMA"],
          Combination = mae_h[, "Combination"], xlab = "months ahead", ylab = "MAE ($ billions)", zero = TRUE,
          title = "The models' edge over seasonal naive shrinks as the horizon grows")

#| **Fan chart with honest ranges.** Like the Studio, the 50% and 80% ranges come from the best method's own past errors at each horizon: the forecast plus the 10th, 25th, 75th and 90th percentiles of those errors. With only 10 to 12 errors per horizon these edges are rough; that is the price of fewer origins. We wrap them in a `forecast` object so `viz_forecast()` can draw it.
q <- apply(errs[[best]], 2, quantile, probs = c(.10, .25, .75, .90), na.rm = TRUE)
point <- fc[[best]]
final <- structure(list(mean = point, x = y, level = c(50, 80), method = best,
                        lower = cbind(`50%` = point + q[2, ], `80%` = point + q[1, ]),
                        upper = cbind(`50%` = point + q[3, ], `80%` = point + q[4, ])), class = "forecast")
viz_forecast(final, from = 2020, ylab = "$ billions", title = sprintf("Retail sales: about $%.0f billion by %s", point[h], format(as.Date(ts_dates(point)[h]), "%B %Y")))

#| **The executive summary, generated from the numbers.** `sprintf()` fills each `%` slot with a value: `%.1f` means one decimal place, `%s` a piece of text, `%%` a literal percent sign. Every number in this paragraph comes from code above, so it updates itself when the data do.
summary_text <- sprintf(
  "We expect U.S. retail sales excluding food services (not seasonally adjusted) to be about $%.1f billion in %s (80%% range $%.1f to $%.1f billion). Over %d forecast origins in the past four years, the most accurate method was %s, with a typical miss of $%.1f billion one month ahead and $%.1f billion %d months ahead, %.0f%% smaller than the seasonal naive rule.",
  point[h], format(as.Date(ts_dates(point)[h]), "%B %Y"), final$lower[h, "80%"], final$upper[h, "80%"],
  length(origins), best, mae_h[1, best], mae_h[h, best], h, 100 * (1 - score[best, "MAE"] / score["Seasonal naive", "MAE"]))
cat(strwrap(summary_text, 90), sep = "\n")
