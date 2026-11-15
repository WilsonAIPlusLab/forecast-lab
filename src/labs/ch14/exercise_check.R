.ff <- function(x) forecast(ets(x, model = "MAM", damped = TRUE), h = 12)
.o <- seq(length(y) - 48, length(y) - 4, by = 4)
.e <- t(sapply(.o, function(o) y[o + 1:12] - as.numeric(.ff(window(y, end = time(y)[o]))$mean)))
.full <- .ff(y); .p <- .full$mean[12]
.q <- quantile(.e[, 12], c(0.10, 0.90), na.rm = TRUE); .m1 <- mean(abs(.e[, 1]), na.rm = TRUE)
.f80 <- forecast(ets(y, model = "MAM", damped = TRUE), h = 12, level = 80)
.num_ok <- exists("point") && exists("lo80") && exists("hi80") && exists("mae1") &&
  isTRUE(all.equal(as.numeric(c(point, lo80, hi80, mae1)), as.numeric(c(.p, .p + .q, .m1)), tolerance = 1e-6))
.txt_ok <- exists("summary_text") && is.character(summary_text) &&
  all(vapply(sprintf("%.1f", c(.p, .p + .q, .m1)), function(s) grepl(s, summary_text, fixed = TRUE), TRUE))
check_that(.num_ok && .txt_ok,
  sprintf("Shipped. Your forecast is $%.1f billion for %s, with an 80%% range $%.1f billion wide ($%.1f billion below the forecast, $%.1f billion above), built from errors the model made at origins it had never seen. Compare the model's own formula-based 80%% interval, forecast(ets(y, model = \"MAM\", damped = TRUE), h = 12, level = 80): $%.1f to $%.1f billion. The two ranges answer different questions: one says how wrong this method has actually been lately, the other what the fitted model believes about its own errors since 2010. Say which one you used. Before sending, add one risk and one trigger, as in the Studio's summary.",
          .p, format(as.Date(ts_dates(.full$mean)[12]), "%B %Y"), diff(.q), -.q[1], .q[2], .f80$lower[12, 1], .f80$upper[12, 1]),
  if (!.num_ok) "A number is off. Check: the model function is ets(); the 80% range uses the errors in column 12 (the 12-month horizon), errs[, 12] or errs[, h]; and nothing else in the code was changed." else
    "The numbers are right but the summary text does not show them all. The last %.1f slot should be filled with mae1, the typical one-month-ahead miss.")
