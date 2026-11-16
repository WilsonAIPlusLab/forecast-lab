# Hidden grader: recomputes the three rolling-origin MAEs and the gain, then checks the student's values.
.o <- seq(length(y) - 48, length(y) - 6, by = 6)
.cv <- function(fun) mean(abs(t(sapply(.o, function(o) y[o + 1:12] - as.numeric(fun(window(y, end = time(y)[o])))))), na.rm = TRUE)
.sn <- .cv(function(x) snaive(x, h = 12)$mean)
.ad <- if (exists("mae_add")) as.numeric(mae_add) else NA   # mae_add has no blank, so it is reused rather than recomputed (saves time)
.mu <- .cv(function(x) forecast(ets(x, model = "MAM", damped = TRUE), h = 12)$mean)
.g <- 100 * (1 - .mu / .ad)
.ok <- exists("mae_snaive") && exists("mae_mul") && exists("gain") &&
  isTRUE(all.equal(as.numeric(c(mae_snaive, mae_add, mae_mul, gain)), c(.sn, .ad, .mu, .g), tolerance = 1e-6))
check_that(.ok,
  sprintf("One change (additive to multiplicative seasonality) lowered the typical miss from $%.1f to $%.1f billion, a %.0f%% gain, and both models beat seasonal naive ($%.1f billion). Because nothing else changed, you can credit the whole gain to that one choice. If you had changed the seasonality, the trend and the sample at once, you could not say which change helped. Note the sample: 8 origins is a small test, so treat a gain of a few percent as a tie.",
          .ad, .mu, .g, .sn),
  if (exists("mae_snaive") && isTRUE(all.equal(as.numeric(mae_snaive), .sn, tolerance = 1e-6)) && exists("mae_mul") && isTRUE(all.equal(as.numeric(mae_mul), .mu, tolerance = 1e-6)))
    "The MAEs are right but the gain is not. The gain compares the new model with the old one: 100 * (1 - mae_mul / mae_add)."
  else "A number is off. Check: the benchmark function is snaive(); the multiplicative model is \"MAM\" (multiplicative error, additive trend, multiplicative seasonality); the gain divides by mae_add; nothing else was changed.")
