#| **Start from the feature table of Lab 12.1.** A hidden setup step has rebuilt it: `d` holds every month, `train` is 1993–2022, `test` is January 2023 onward (45 months), and `features` lists the seven predictors. Each test row uses only information published by the middle of that month (last month's sales, sentiment and unemployment), so every forecast below is a genuine **one-month-ahead** forecast.
c(train_months = nrow(train), test_months = nrow(test))
X <- function(df) xgb.DMatrix(as.matrix(df[, features]), label = df$growth)

#| **Tune on rolling folds, never on the test set.** Each fold pretends it is the start of one year (2019, 2020, 2021, 2022), trains on everything before it, and scores that year. We try four combinations of learning rate (0.1, 0.3) and depth (2, 3). Early stopping picks the number of trees inside each fold: it stops once the fold's validation error has not improved for 20 rounds. (Adding a learning rate of 0.05 to the grid makes the lab slower in the browser and picks the same winner.)
grid <- expand.grid(eta = c(0.1, 0.3), max_depth = c(2, 3))
for (g in seq_len(nrow(grid))) {
  p <- list(eta = grid$eta[g], max_depth = grid$max_depth[g], tree_method = "exact", nthread = 1)
  scores <- sapply(2019:2022, function(yr) {
    a <- d[d$date < as.Date(sprintf("%d-01-01", yr)), ]
    b <- d[format(d$date, "%Y") == yr, ]
    m <- xgb.train(params = p, data = X(a), nrounds = 500, evals = list(valid = X(b)),
                   early_stopping_rounds = 20, verbose = 0)
    unlist(attributes(m)$early_stop[c("best_score", "best_iteration")])
  })
  grid$cv_rmse[g] <- mean(scores[1, ]); grid$rounds[g] <- round(mean(scores[2, ]))
}
grid[order(grid$cv_rmse), ]

#| **Refit the winner on all of 1993–2022 and forecast the test months.** The model predicts growth; we convert it to dollars with last month's actual sales.
best <- grid[which.min(grid$cv_rmse), ]
fit <- xgb.train(params = list(eta = best$eta, max_depth = best$max_depth, tree_method = "exact", nthread = 1),
                 data = X(train), nrounds = best$rounds)
f_xgb <- test$lag1 * (1 + predict(fit, X(test)) / 100)

#| **Three rivals on exactly the same months:**
#| - **Random forest** (Chapter 11) on the same features, with `randomForest`. It refuses missing values, so we fill the one gap (November 2025's lagged unemployment rate) with the month before. XGBoost needed no such fix.
#| - **ETS(M,A,M)**, the model `ets()` selects automatically for this series (drop `model = "MAM"` to check; it is just slower). We fit it on data through 2022, then run it forward over the test months *without re-estimating*. Its fitted values are one-month-ahead forecasts, just like ours.
#| - **Seasonal naive**: same month last year.
suppressPackageStartupMessages(library(randomForest)); library(forecast)
set.seed(12)
rf <- randomForest(growth ~ ., data = train[, c("growth", features)], ntree = 300)
test_rf <- test; gap <- which(is.na(test_rf$unrate_lm)); test_rf$unrate_lm[gap] <- test_rf$unrate_lm[gap - 1]
f_rf <- test$lag1 * (1 + predict(rf, test_rf) / 100)
fit_ets <- ets(window(retail, end = c(2022, 12)), model = "MAM")
f_ets <- as.numeric(window(fitted(ets(retail, model = fit_ets, use.initial.values = TRUE)), start = c(2023, 1)))
f_snaive <- d$sales[match(as.Date(sprintf("%d-%s", as.integer(substr(test$date, 1, 4)) - 1, substr(test$date, 6, 10))), d$date)]

#| **Add a combination.** The simplest ensemble there is: the average of XGBoost and ETS. Combining models that make *different kinds* of mistakes is the most reliable trick in the M-competitions.
f_combo <- (f_xgb + f_ets) / 2
score <- function(f) { e <- (test$sales - f) / 1000
  c(`ME ($bn)` = mean(e), `MAE ($bn)` = mean(abs(e)), `RMSE ($bn)` = sqrt(mean(e^2)), `MAPE (%)` = 100 * mean(abs(e * 1000 / test$sales))) }
scores <- rbind(XGBoost = score(f_xgb), `Random forest` = score(f_rf), ETS = score(f_ets),
                `XGBoost + ETS average` = score(f_combo), `Seasonal naive` = score(f_snaive))
scores

#| **The scorecard.** Green marks the best value in each column. Read it honestly: on one long, well-behaved series, tuned boosting does **not** beat ETS, and the random forest does better than boosting. Averaging XGBoost with ETS gives the lowest RMSE, so it avoids the big misses best.
viz_table(scores, highlight = c("MAE ($bn)", "RMSE ($bn)", "MAPE (%)"), digits = 2,
          title = "On one series, boosting does not beat ETS; averaging the two avoids the big misses")
as_ts <- function(v) ts(v, start = c(2023, 1), frequency = 12)
viz_compare(history = window(retail, start = c(2020, 1), end = c(2022, 12)), actual = window(retail, start = c(2023, 1)),
            XGBoost = as_ts(f_xgb), ETS = as_ts(f_ets), title = "Both models track the December peaks one month ahead")
