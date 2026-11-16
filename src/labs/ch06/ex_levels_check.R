# Hidden check for ex_levels: the same model fitted to log prices with d = 1 gives the level forecast directly.
.p <- fred("PCEPILFE", start = c(2000, 1), quiet = TRUE)
.f <- forecast::forecast(forecast::Arima(100 * diff(log(.p)), order = c(1, 0, 1), include.mean = TRUE), h = 12)$mean
.last <- as.numeric(tail(.p, 1))
.lv <- .last * exp(cumsum(.f) / 100)
.alt <- exp(forecast::forecast(forecast::Arima(log(.p), order = c(1, 1, 1), include.drift = TRUE), h = 12)$mean[12])
check_that(exists("level") && length(level) == 12 && max(abs(as.numeric(level) - .lv)) < 1e-6 &&
             exists("infl_12") && abs(infl_12 - 100 * (.lv[12] / .last - 1)) < 1e-6,
  sprintf("Right: the index is forecast at %.2f in September 2027 (from %.2f), so 12-month core inflation is %.2f%%. You undid the two transformations in reverse order: cumsum() undoes the difference, exp() undoes the log. That is what forecast() does for you when you fit the same model to log prices with d = 1, ARIMA(1,1,1) with drift: its September 2027 index forecast is %.2f. Also notice that 12-month inflation is exp(sum of the 12 monthly log changes) - 1. (Chapter 10 explains why exp() of a log forecast is a median, not a mean.)",
          .lv[12], .last, 100 * (.lv[12] / .last - 1), .alt),
  "Undo the transformations in reverse order: first a running total of the monthly log changes, cumsum(); then exp() to undo the log. The 12-month rate compares the September 2027 level with the latest observed level, as.numeric(tail(pce, 1)).")
