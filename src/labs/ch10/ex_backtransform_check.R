# Hidden check for ex_backtransform: compares the three back-transformed numbers with the right answers.
.med <- exp(mu); .band <- exp(c(lo, hi)); .mean <- .med * exp(sigma^2 / 2)
.ok <- exists("median_price") && exists("band") && exists("mean_price") && length(band) == 2 &&
  abs(median_price - .med) < 1e-6 && all(abs(band - .band) < 1e-6) && abs(mean_price - .mean) < 1e-6
check_that(.ok,
  sprintf("Median $%.2f, 80%% band $%.2f to $%.2f, mean $%.2f per barrel. The band reaches $%.2f below the median but $%.2f above it: in dollars, a log model's band is lopsided because prices can rise more than 100%% but cannot fall below zero. The mean sits %.1f%% above the median, so a fuel budget that adds up across months should use the mean. R does all of this for you with forecast(ets(oil, lambda = 0), h = 12, biasadj = TRUE).",
          .med, .band[1], .band[2], .mean, .med - .band[1], .band[2] - .med, 100 * (.mean / .med - 1)),
  "Check the three blanks. exp() undoes log(), for the point and for each band endpoint (the lower one is stored in lo). The mean needs the extra factor exp(sigma^2 / 2): square the log-scale spread, then halve it.")
