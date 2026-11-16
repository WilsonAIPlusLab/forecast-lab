# Hidden check (not shown to students): rebuilds the honest feature and compares the test MAE.
.d <- d; .d$roll3 <- lag_k(as.numeric(stats::filter(x, rep(1/3, 3), sides = 1)), 1)
.tr <- na.omit(.d[.d$date < "2023-01-01", ]); .te <- .d[.d$date >= "2023-01-01", ]
set.seed(1); .m <- randomForest(g ~ g1 + g2 + roll3, data = .tr, ntree = 300, mtry = 2)
.truth <- mean(abs(.te$g - predict(.m, .te)))
check_that(exists("mae_honest") && exists("mae_leaky") && isTRUE(all.equal(d$roll3, .d$roll3)) && abs(mae_honest - .truth) < 1e-6,
  sprintf("Fixed. The leaky forest 'misses' by only %.2f points on the 2023+ test months; the honest one by %.2f. The leak flattered the test score too, because the test rows were built with the same leaky formula. A held-out test set cannot catch a leak in the features: only checking every window can. Rule of thumb: in a forecasting table, every rolling statistic gets a lag of at least 1.", mae_leaky, .truth),
  "Not yet. Blank 1 is how many rows to shift the colleague's mean so its window ends last month (a small whole number). Blank 2 is the actual growth on the test rows: the column test$g. Don't change the seed or the settings.")
