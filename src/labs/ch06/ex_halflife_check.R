# Hidden check for ex_halflife.
.s <- fred("UMCSENT", start = 1990, end = c(2019, 12), quiet = TRUE)
.f <- forecast::Arima(.s, order = c(1, 0, 0), include.mean = TRUE)
.phi <- unname(coef(.f)["ar1"]); .hl <- log(0.5) / log(.phi)
.adf <- suppressWarnings(tseries::adf.test(.s)$p.value)
check_that(exists("half_life") && abs(half_life - .hl) < 1e-6 && exists("gap12") && abs(gap12 - 10 * .phi^12) < 1e-6,
  sprintf("Right. phi = %.3f: each month, %.1f%% of any gap from the long-run mean (%.1f) survives. Half of a shock is gone after %.1f months, and a 10-point drop is still %.1f points a year later. In words for your manager: \"sentiment shocks are persistent but not permanent; expect about half of a drop to be undone within a year.\" Note that ADF cannot reject a unit root for this series (p = %.2f): with phi this close to 1 the test has little power, and an index that stayed between about 55 and 112 over these 30 years cannot wander forever.",
          .phi, 100 * .phi, unname(coef(.f)["intercept"]), .hl, 10 * .phi^12, .adf),
  "Three blanks: the AR order is 1; the half-life puts log(0.5) on top, because half of the shock is left; and the gap after a year uses phi to the power 12.")
