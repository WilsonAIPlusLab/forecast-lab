#| **Same three series**, but this time we keep data through 2002 so that we have something to forecast.
library(vars)
q <- function(id) fred(id, to = "quarter")
d <- na.omit(ts.intersect(400 * diff(log(q("CPIAUCSL"))), q("UNRATE"), q("FEDFUNDS")))
colnames(d) <- c("infl", "unemp", "ffr")
y <- window(d, start = c(1960, 1), end = c(2000, 4))

#| **One forecast, drawn as a fan.** `predict(m, n.ahead = 8)` iterates the VAR forward: each forecast quarter feeds the next. Every variable gets a point forecast and a 95% interval. We pack the unemployment forecast into the shape `viz_forecast()` expects and overlay what really happened. Standing at the end of 2000, with unemployment at a 30-year low of 3.9%, the VAR expects it to drift back up, to about 4.8% by the end of 2002. The March–November 2001 recession pushed it up about twice as far, to 5.9%, near the top of the 95% band.
m  <- VAR(y, p = 4, type = "const")
pr <- predict(m, n.ahead = 8, ci = 0.95)$fcst$unemp
mk <- function(v) ts(v, start = c(2001, 1), frequency = 4)
fc <- list(x = y[, "unemp"], mean = mk(pr[, "fcst"]), level = 95, method = "VAR(4)",
           lower = matrix(pr[, "lower"], dimnames = list(NULL, "95%")),
           upper = matrix(pr[, "upper"], dimnames = list(NULL, "95%")))
viz_forecast(fc, actual = window(d[, "unemp"], start = c(2001, 1), end = c(2002, 4)), from = 1995,
             title = "The VAR saw unemployment rising, but the 2001 recession doubled the rise", ylab = "unemployment rate, %")

#| **One forecast proves nothing: roll the origin.** For every quarter from 1990Q4 to 1999Q4 we refit on data up to that quarter and forecast 4 quarters (one year) ahead with three methods: the VAR(4); a univariate AR(4) for each variable (`ar()`, an ARIMA(4,0,0)); and the naive "no change" forecast. 37 origins × 3 variables.
H <- 4
origins <- seq(1990.75, 2000.75 - H / 4, by = 0.25)
err <- array(NA, c(length(origins), 3, 3), dimnames = list(NULL, colnames(y), c("VAR(4)", "AR(4)", "Naive")))
for (i in seq_along(origins)) {
  tr  <- window(y, end = origins[i])
  act <- y[nrow(tr) + H, ]                    # the actual value H quarters after the origin
  fv  <- predict(VAR(tr, p = 4, type = "const"), n.ahead = H)$fcst
  for (v in colnames(y)) {
    fa <- predict(ar(tr[, v], aic = FALSE, order.max = 4, method = "ols"), n.ahead = H)$pred
    err[i, v, ] <- act[v] - c(fv[[v]][H, "fcst"], fa[H], tail(tr[, v], 1))
  }
}

#| **The scorecard (RMSE, percentage points).** Lower is better; green marks the winner in each column. Be honest about what it shows. The VAR wins only for the **funds rate**, which makes sense: the Fed reacts to inflation and unemployment, so their lags carry real information about future rates. For **inflation** the VAR is clearly worse than the AR(4) (extra coefficients add noise), and for unemployment it is slightly worse. A small VAR's main value is **structure** (impulse responses, scenarios), not raw accuracy.
rmse <- apply(err, c(3, 2), function(e) sqrt(mean(e^2)))
viz_table(rmse, highlight = colnames(y), digits = 3,
          title = "One year ahead, 1991–2000: the VAR wins only for the funds rate")
rmse
