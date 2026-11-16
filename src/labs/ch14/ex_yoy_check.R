# Hidden grader: recomputes the forecast and the like-with-like comparisons, then checks the student's values.
.f <- as.numeric(forecast(ets(y, model = "MAM", damped = TRUE), h = 12)$mean)
.ly <- as.numeric(tail(y, 12)); .v <- 100 * (.f / .ly - 1); .tg <- 100 * (sum(.f) / sum(.ly) - 1)
.ok <- exists("vs_last_year") && exists("total_growth") && length(vs_last_year) == 12 &&
  isTRUE(all.equal(as.numeric(c(vs_last_year, total_growth)), c(.v, .tg), tolerance = 1e-6))
.vl <- 100 * (.f / as.numeric(tail(y, 1)) - 1)
check_that(.ok,
  sprintf("Measured against the latest month, the forecasts swing from %+.0f%% to %+.0f%%: that is the calendar talking, not the economy. Measured against the same month a year earlier they sit between %+.1f%% and %+.1f%%, and the next 12 months as a whole are %+.1f%% on the last 12. For data that are not seasonally adjusted, always compare like with like: same month last year, or 12-month totals.",
          min(.vl), max(.vl), min(.v), max(.v), .tg),
  "A number is off. Check: last_year holds the last 12 actual months, tail(y, 12); vs_last_year divides the forecast by last_year; total_growth compares sum(fc) with sum(last_year).")
