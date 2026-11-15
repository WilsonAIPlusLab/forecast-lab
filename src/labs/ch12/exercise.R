# The tuned model from Lab 12.2 (the feature table is already built for you)
fit <- xgb.train(params = list(eta = 0.1, max_depth = 2, tree_method = "exact", nthread = 1),   # tuned settings
                 data = xgb.DMatrix(as.matrix(train[, features]), label = train$growth), nrounds = 38)   # 38 trees
nov <- test[test$date == as.Date("2025-11-01"), ]       # the month to explain
dnov <- xgb.DMatrix(as.matrix(nov[, features]))          # its features, in XGBoost's data format

# 1. Ask XGBoost for the SHAP values of November 2025
# blank: the logical value that switches on per-feature contributions
S <- predict(fit, dnov, predcontrib = ______)

# 2. Rebuild the dollar forecast from the SHAP values alone:
#    last month's sales x (1 + (base value + all contributions) / 100)
# blank: one number, the total of every column of S
forecast_from_shap <- nov$lag1 * (1 + ______ / 100)

# 3. Which feature pulled November's forecast DOWN the most?
biggest_drag <- names(which.min(S[1, features]))         # feature with the most negative contribution
c(forecast_bn = forecast_from_shap / 1000, actual_bn = nov$sales / 1000)   # forecast vs actual, $ billions
biggest_drag
