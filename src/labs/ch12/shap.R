#| **Refit the tuned model from Lab 12.2.** The hidden setup rebuilt the feature table (`train` = 1993–2022, `test` = 2023 onward). Tuning chose a learning rate of 0.1, depth-2 trees and 38 rounds.
params <- list(eta = 0.1, max_depth = 2, tree_method = "exact", nthread = 1)
dtrain <- xgb.DMatrix(as.matrix(train[, features]), label = train$growth)
dtest  <- xgb.DMatrix(as.matrix(test[, features]))
fit    <- xgb.train(params = params, data = dtrain, nrounds = 38)
pred   <- predict(fit, dtest)            # predicted growth, % over last month

#| **Ask for SHAP values.** `predcontrib = TRUE` returns one row per month and one column per feature, plus an `(Intercept)` column: the **base value**, the model's average prediction. Each feature column says how many percentage points of growth that feature added or removed *for that month*.
S <- predict(fit, dtest, predcontrib = TRUE)
round(tail(S, 3), 2)

#| **Check the additivity property.** For every month, base value + all contributions = the prediction, exactly. This is what makes SHAP so easy to explain: the bars of a waterfall chart literally add up to the forecast.
all.equal(as.numeric(rowSums(S)), as.numeric(pred), tolerance = 1e-5)

#| **Translate into dollars.** Our forecast is *last month × (1 + growth/100)*, so a contribution of *c* points of growth is worth *last month × c/100* dollars. Multiplying every column by the same amount keeps everything additive. We divide by 1,000 to get billions.
usd <- S * test$lag1 / 100 / 1000       # $ billions
dec <- which(test$date == as.Date("2025-12-01"))
round(usd[dec, ], 1)

#| **Draw the waterfall for December 2025.** Start from November's sales, add the base value (an average month's growth), then each feature's push. The bars end exactly at the forecast. `viz_custom("waterfall", ...)` is a chart type this chapter adds to the site.
nice <- c(month = "Calendar month", growth_ly = "Same month last year's growth", growth_lm = "Last month's growth",
          yoy_lm = "Last month's 12-month growth", weekend = "Weekend days", sent_lm = "Consumer sentiment (last month)",
          unrate_lm = "Unemployment rate (last month)")
waterfall <- function(row, contrib_usd, growth_pred, title) {
  v <- contrib_usd[features]; o <- order(-abs(v))
  fc <- row$lag1 * (1 + growth_pred / 100) / 1000
  viz_custom("waterfall", title = title, unit = "$bn",
    subtitle = sprintf("Starts from last month's sales ($%.1fbn) and ends at the forecast ($%.1fbn). Actual: %s.", row$lag1 / 1000, fc,
                       if (is.na(row$sales)) "not yet known" else sprintf("$%.1fbn", row$sales / 1000)),
    start = row$lag1 / 1000, start_label = "Last month's sales", base = contrib_usd[["(Intercept)"]],
    labels = unname(nice[features[o]]), values = unname(v[o]),
    feature_values = unname(as.numeric(row[features[o]])), total_label = "Forecast")
}
waterfall(test[dec, ], usd[dec, ], pred[dec], "December 2025: last year's December jump does most of the lifting")

#| **From one month to all months: global importance.** Average the *absolute* SHAP values over the 45 test months. This says how much each feature moves the forecast in a typical month, in dollars, which is easier to explain than "gain".
imp <- colMeans(abs(usd[, features]))
viz_bars(imp, unname(nice[names(imp)]), xlab = "Mean |SHAP|, $ billions",
         title = "Seasonal features move the forecast most; macro drivers barely register",
         subtitle = "Average absolute SHAP value per feature, one-month-ahead forecasts, Jan 2023 to Sep 2026")

#| **Next month's forecast, explained.** In production you refit on all the data you have (through September 2026) and forecast October 2026, the first month nobody has seen. `make_features(retail, extra_month = TRUE)` adds that month's row; its features are all known today.
full <- d[!is.na(d$growth), ]
fit_all <- xgb.train(params = params, nrounds = 38,
                     data = xgb.DMatrix(as.matrix(full[, features]), label = full$growth))
nxt <- tail(make_features(retail, extra_month = TRUE), 1)
dnext <- xgb.DMatrix(as.matrix(nxt[, features]))
waterfall(nxt, predict(fit_all, dnext, predcontrib = TRUE)[1, ] * nxt$lag1 / 100 / 1000, predict(fit_all, dnext),
          "October 2026: the forecast, and why")
