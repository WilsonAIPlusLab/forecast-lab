.gap  <- lag_k(100 * log(as.numeric(permits) / as.numeric(starts)), 1)
.d    <- d; .d$gap1 <- .gap
.tr   <- na.omit(.d[.d$date < "2023-01-01", ]); .te <- .d[.d$date >= "2023-01-01", ]
set.seed(1); .m <- randomForest(g ~ g1 + g2 + g12 + gap1, data = .tr, ntree = 300, mtry = 2)
.truth <- mean(abs(.te$level - .te$prev * exp(predict(.m, .te) / 100)))
check_that(exists("mae_plus") && exists("mae_base") && abs(mae_plus - .truth) < 1e-6 && "gap1" %in% names(train),
  sprintf("With the permits gap, the forest's one-month-ahead MAE drops from %.1f to %.1f thousand units (annual rate). Permits are the paperwork that comes before a start, so a big pile of permits relative to starts signals starts to come. Now try the growth of permits instead, lag_k(100 * c(NA, diff(log(permits))), 1). It does not help at all (MAE about 84): the size of the pipeline matters, not its last wiggle. For reference, the naive forecast (last month's level) misses by 95.4 on average.", mae_base, .truth),
  "Check both blanks: the first is the permits series (the numerator of the gap), the second adds the new column gap1 to the forest's formula. Don't change the seed or the settings.")
