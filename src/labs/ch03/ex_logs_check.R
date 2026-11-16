# Hidden check for ex_logs: the log model scored in $ millions, plus the (wrong) log-scale MAE for the message.
.fb <- exp(rwf(log(train), h = h, drift = TRUE)$mean); .t <- mean(abs(test - .fb)); .l <- mean(abs(test - rwf(train, h = h, drift = TRUE)$mean))
.g <- 100 * (exp(12 * mean(diff(log(train)))) - 1); .w <- mean(abs(log(test) - log(.fb)))
check_that(exists("mae_log") && is.numeric(mae_log) && abs(mae_log - .t) < 1e-6,
  sprintf("In $ millions: drift on levels misses by %s a month, drift on logs by %s. The log model assumed the 2015-22 growth rate (%.1f%% a year, boosted by the 2020 jump) would continue, and it did not. Had you scored the log model on the log scale, you would have reported %.3f, a number that cannot be compared with %s at all. Always transform back, then score in the original units.", format(round(.l), big.mark = ","), format(round(.t), big.mark = ","), .g, .w, format(round(.l), big.mark = ",")),
  "log() is undone by exp(). Then score the back-transformed forecast f_back against test, so both MAEs are in $ millions.")
