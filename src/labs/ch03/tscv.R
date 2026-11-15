#| **Use only pre-COVID data** (2010 to 2019) so a one-off shock doesn't dominate the lesson.
library(forecast)                             # Hyndman's forecasting package
retail <- fred("RSXFSN", start = 2010, end = c(2019, 12))   # monthly retail sales, $ millions, NSA, 2010-2019

#| **Time-series cross-validation in one line.** `tsCV()` rolls the forecast origin forward one month at a time. At each origin it re-fits the method on the data so far and forecasts 1 to 12 months ahead. The result is a 120 × 12 matrix of errors: one row per origin, one column per horizon. Rows where a method cannot run yet (seasonal naive needs a full year of data) are `NA`.
e_snaive <- tsCV(retail, snaive, h = 12)      # rolling-origin errors of seasonal naive, 1 to 12 months ahead
e_drift  <- tsCV(retail, rwf, drift = TRUE, h = 12)   # same for drift (extra arguments go to rwf)
dim(e_snaive)                                 # rows = origins, columns = horizons

#| **Average the absolute errors down each column** to get MAE at every horizon. `na.rm = TRUE` skips origins too close to the end of the data to be scored.
mae_snaive <- colMeans(abs(e_snaive), na.rm = TRUE)   # MAE for horizons 1 to 12
mae_drift  <- colMeans(abs(e_drift),  na.rm = TRUE)
round(rbind(`Seasonal naive` = mae_snaive, Drift = mae_drift))   # one row per method, one column per horizon

#| **Plot error against horizon.** This is how professionals report accuracy: not one number, but a curve. Seasonal naive is flat at about 14 billion dollars; drift misses by roughly two to three times as much until horizon 12, where it briefly improves because the last observation is from the same month a year earlier.
viz_lines(1:12, `Seasonal naive` = mae_snaive, Drift = mae_drift,   # x = months ahead, one line per method
          xlab = "months ahead", ylab = "MAE ($ millions)", zero = TRUE,   # zero = TRUE starts the y-axis at 0
          title = "Seasonal naive beats drift at every horizon")

#| **Is the difference real, or luck?** The Diebold–Mariano test compares two sets of one-step-ahead errors, using squared errors by default (`power = 2`). The null hypothesis is that both methods are equally accurate. Here DM ≈ −4.5 with p < 0.001: the negative sign means the first method (seasonal naive) has the smaller errors, and the gap is far too large to be luck.
e1 <- e_snaive[, 1]; e2 <- e_drift[, 1]       # [, 1] = first column: the one-step-ahead errors
ok <- !is.na(e1) & !is.na(e2)                 # origins where both methods have an error
dm.test(e1[ok], e2[ok], h = 1)                # Diebold-Mariano test of equal accuracy
