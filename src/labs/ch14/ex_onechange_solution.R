library(forecast)                                # ets(), snaive(), forecast()
y <- fred("RSXFSN", start = 2010) / 1000         # U.S. retail sales, $ billions per month, NOT seasonally adjusted
h <- 12                                          # forecast 1 to 12 months ahead
origins <- seq(length(y) - 48, length(y) - 6, by = 6)   # 8 forecast origins, one every 6 months over four years

# Rolling-origin MAE of one forecasting function: re-fit at every origin on the data up to that origin only
cv_mae <- function(fc_fun) {
  # sapply loops over origins; each row = actual minus forecast for horizons 1..12 (NA past the end of the data)
  errs <- t(sapply(origins, function(o) y[o + 1:h] - as.numeric(fc_fun(window(y, end = time(y)[o])))))
  mean(abs(errs), na.rm = TRUE)                  # average absolute miss over all origins and horizons
}

# The benchmark and two models that differ in ONE choice only: the type of seasonality
mae_snaive <- cv_mae(function(x) snaive(x, h = h)$mean)                                         # same month last year
mae_add <- cv_mae(function(x) forecast(ets(x, model = "AAA", damped = TRUE), h = h)$mean)     # seasonal swings of fixed size
mae_mul <- cv_mae(function(x) forecast(ets(x, model = "MAM", damped = TRUE), h = h)$mean)     # swings that scale with the level

# The single change, judged by how much it lowers the error
gain <- 100 * (1 - mae_mul / mae_add)            # % reduction in MAE from additive to multiplicative
c(`Seasonal naive` = mae_snaive, Additive = mae_add, Multiplicative = mae_mul, `Gain (%)` = gain)
sprintf("Switching from additive to multiplicative seasonality, with nothing else changed, cut the typical miss from $%.1f to $%.1f billion (%.0f%%). Both beat the seasonal naive benchmark ($%.1f billion).",
        mae_add, mae_mul, gain, mae_snaive)
