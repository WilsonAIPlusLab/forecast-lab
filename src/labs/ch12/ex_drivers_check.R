# Hidden check (not shown to students): recomputes the dollar SHAP values and the top three drivers.
.u <- predict(fit, xgb.DMatrix(as.matrix(mar[, features])), predcontrib = TRUE)[1, features] * mar$lag1 / 100 / 1000
.t <- names(head(.u[order(-abs(.u))], 3))
check_that(exists("usd") && length(usd) == length(features) && isTRUE(all.equal(unname(usd), unname(.u), tolerance = 1e-6)) &&
             exists("top3") && identical(names(top3), .t),
  sprintf("Three reasons, in dollars: %s. Notice how the first sentence leads with the number, the second gives the reasons, and the third says how far to trust them. That is the whole manager briefing. Units check: 1 point of growth on February's $%.1fbn is worth $%.1fbn.",
          paste(sprintf("%s %+.1fbn", .t, .u[.t]), collapse = ", "), mar$lag1 / 1000, mar$lag1 / 100 / 1000),
  if (exists("usd") && isTRUE(all.equal(unname(usd), unname(.u), tolerance = 1e-6)))
    "The dollars are right, but the top three are not. Sort by the size of each push, ignoring its sign: abs(usd)." else
    "Check the multiplier: points of growth x last month's sales (mar$lag1, in $ millions) / 100 gives $ millions; divide by 1,000 more for $ billions.")
