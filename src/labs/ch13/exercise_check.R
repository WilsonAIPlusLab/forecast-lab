.tr <- lapply(parts, window, end = c(2025, 9))
.fc <- sapply(.tr, function(s) forecast(ets(s, model = "ZZN"), h = 12)$mean)
.bu <- rowSums(.fc)
.dir <- forecast(ets(window(total, end = c(2025, 9)), model = "ZZN"), h = 12)$mean
.m1 <- mean(abs(test_total - .bu)); .m2 <- mean(abs(test_total - .dir))
check_that(exists("bu_total") && length(bu_total) == 12 && max(abs(as.numeric(bu_total) - .bu)) < 1e-6,
  sprintf("Bottom-up MAE = %s vs %s for the direct total forecast ($ millions). Bonus fact: with a linear method such as drift, bottom-up and direct give exactly the same total, because the slope of a sum is the sum of the slopes. (That holds when the total really equals the sum of its parts in the data.) With ets(), each series gets its own fitted model, so the parts no longer have to add up to the total's forecast. That is when reconciliation matters.",
          format(round(.m1), big.mark = ","), format(round(.m2), big.mark = ",")),
  "Check two things. `forecast()` stores its point forecasts in `$mean`. The bottom-up total adds the two columns of fc_parts in each row, so use rowSums().")
