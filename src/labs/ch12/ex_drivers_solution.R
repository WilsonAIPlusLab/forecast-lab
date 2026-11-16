# Your manager: "Sales jumped in March 2026. Why did our model see it coming? Give me three reasons, in dollars."
# The tuned model from Lab 12.2 (the feature table is already built for you)
fit <- xgb.train(params = list(eta = 0.1, max_depth = 2, tree_method = "exact", nthread = 1),   # tuned settings
                 data = xgb.DMatrix(as.matrix(train[, features]), label = train$growth), nrounds = 38)   # 38 trees
mar <- test[test$date == as.Date("2026-03-01"), ]       # the month to explain (one row)
S <- predict(fit, xgb.DMatrix(as.matrix(mar[, features])), predcontrib = TRUE)   # SHAP, % points of growth

# 1. Convert the seven feature contributions from % points of growth into $ billions.
#    1 point of growth is worth 1% of last month's sales; lag1 is in $ millions.
usd <- S[1, features] * mar$lag1 / 100 / 1000     # points -> % of last month -> $ millions -> $ billions

# 2. Keep the three features that moved the forecast most, up OR down.
top3 <- head(usd[order(-abs(usd))], 3)          # sort by size, ignoring the sign

# 3. The three sentences for your manager
fc <- mar$lag1 * (1 + sum(S) / 100) / 1000              # the forecast, $ billions (base + all pushes)
cat(sprintf("We expected March 2026 sales of $%.1f billion, up from $%.1f billion in February.\n", fc, mar$lag1 / 1000))
cat(sprintf("The biggest drivers: %s.\n", paste(sprintf("%s (%+.1f bn)", names(top3), top3), collapse = ", ")))
cat(sprintf("Actual sales came in at $%.1f billion; these are the model's reasons, not proof of cause.\n", mar$sales / 1000))
