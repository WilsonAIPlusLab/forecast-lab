# Hidden check for ex_window: refit both windows and compare the MAEs.
.s <- window(food, start = c(2021, 1), end = c(2025, 8)); .l <- window(food, end = c(2025, 8))
.fs <- ets(.s); .fl <- ets(.l)
.ms <- accuracy(forecast(.fs, h = 12), test)["Test set", "MAE"]; .ml <- accuracy(forecast(.fl, h = 12), test)["Test set", "MAE"]
.qs <- accuracy(forecast(.fs, h = 12), test)["Test set", "MASE"]; .ql <- accuracy(forecast(.fl, h = 12), test)["Test set", "MASE"]
check_that(exists("mae") && length(mae) == 2 && isTRUE(all(abs(mae - c(.ml, .ms)) < 1e-6)),
  sprintf("Starting in 2021 cuts the test MAE from about $%s million to $%s million a month. With 2020 inside the window, ets() picks %s with alpha = %.2f: to survive the collapse, the level must jump to every new month. From 2021 it picks %s with alpha = %.2f, a calmer memory. Notice the trap: the MASEs are %.2f and %.2f, each scaled by a different window's in-sample error, so always compare windows in dollars on the same test months.",
          format(round(.ml), big.mark = ","), format(round(.ms), big.mark = ","), .fl$method, .fl$par[["alpha"]], .fs$method, .fs$par[["alpha"]], .ql, .qs),
  "Check the blanks: the short window starts in 2021; the horizon is 12 (or length(test)); and the column name is \"MAE\" in capitals.")
