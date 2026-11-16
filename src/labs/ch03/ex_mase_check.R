# Hidden check for ex_mase: compare with forecast::accuracy(), which uses the same scaling.
.acc <- function(y) { tr <- window(y, end = c(2022, 12)); te <- window(y, start = c(2023, 1)); accuracy(snaive(tr, h = length(te)), te)["Test set", "MASE"] }
.truth <- c(.acc(fred("RSXFSN", start = 2010, quiet = TRUE)), .acc(fred("HOUSTNSA", start = 2010, quiet = TRUE)))
check_that(exists("result") && is.numeric(result) && length(result) == 2 && all(abs(result - .truth) < 1e-6),
  sprintf("MASE: retail %.2f, housing starts %.2f. The MAEs (about 24,800 $ millions vs 18 thousand homes) cannot be compared, but MASE can: the retail forecast missed only about 4%% more than its benchmark's typical in-sample miss, while the housing forecast missed about 67%% more. accuracy() gives exactly the same numbers.", .truth[1], .truth[2]),
  "Seasonal naive compares each month with the same month a year earlier, so the lag is 12 for monthly data. Then divide the test-set MAE by scale.")
