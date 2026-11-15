#| **Refit the tuned model from Lab 13.2.** The hidden setup rebuilt the feature table (`train` = 1993–2022, `test` = 2023 onward). Tuning chose a learning rate of 0.1, depth-2 trees and 38 rounds.
params <- list(eta = 0.1, max_depth = 2, tree_method = "exact", nthread = 1)   # the tuned settings
dtrain <- xgb.DMatrix(as.matrix(train[, features]), label = train$growth)   # training features + target
dtest  <- xgb.DMatrix(as.matrix(test[, features]))                         # test features only
fit    <- xgb.train(params = params, data = dtrain, nrounds = 38)          # 38 trees
pred   <- predict(fit, dtest)            # predicted growth, % over last month

#| **Ask for SHAP values.** `predcontrib = TRUE` returns one row per month and one column per feature, plus an `(Intercept)` column: the **base value**, the model's average prediction. Each feature column says how many percentage points of growth that feature added or removed *for that month*.
S <- predict(fit, dtest, predcontrib = TRUE)   # SHAP matrix: months x (7 features + base value)
round(tail(S, 3), 2)                     # the last 3 test months

#| **Check the additivity property.** For every month, base value + all contributions = the prediction, exactly. This is what makes SHAP so easy to explain: the bars of a waterfall chart literally add up to the forecast.
all.equal(as.numeric(rowSums(S)), as.numeric(pred), tolerance = 1e-5)   # TRUE if each row sums to its prediction

#| **Translate into dollars.** Our forecast is *last month × (1 + growth/100)*, so a contribution of *c* points of growth is worth *last month × c/100* dollars. Multiplying every column by the same amount keeps everything additive. We divide by 1,000 to get billions.
usd <- S * test$lag1 / 100 / 1000       # $ billions
dec <- which(test$date == as.Date("2025-12-01"))   # row number of December 2025
round(usd[dec, ], 1)                     # usd[row, ] = all columns of that row

#| **Draw the waterfall for December 2025.** Start from November's sales, add the base value (an average month's growth), then each feature's push. The bars end exactly at the forecast. `viz_custom("waterfall", ...)` is a chart type this chapter adds to the site.
# readable labels for the chart, keyed by column name
nice <- c(month = "Calendar month", growth_ly = "Same month last year's growth", growth_lm = "Last month's growth",
          yoy_lm = "Last month's 12-month growth", weekend = "Weekend days", sent_lm = "Consumer sentiment (last month)",
          unrate_lm = "Unemployment rate (last month)")
# helper: waterfall chart for one month (row), from its dollar SHAP values and predicted growth
waterfall <- function(row, contrib_usd, growth_pred, title) {
  v <- contrib_usd[features]; o <- order(-abs(v))   # feature contributions, biggest push first
  fc <- row$lag1 * (1 + growth_pred / 100) / 1000   # the forecast, $ billions
  viz_custom("waterfall", title = title, unit = "$bn",
    subtitle = sprintf("Starts from last month's sales ($%.1fbn) and ends at the forecast ($%.1fbn). Actual: %s.", row$lag1 / 1000, fc,
                       if (is.na(row$sales)) "not yet known" else sprintf("$%.1fbn", row$sales / 1000)),
    start = row$lag1 / 1000, start_label = "Last month's sales", base = contrib_usd[["(Intercept)"]],   # first bars
    labels = unname(nice[features[o]]), values = unname(v[o]),                # one bar per feature, in order o
    feature_values = unname(as.numeric(row[features[o]])), total_label = "Forecast")   # each feature's value that month
}
waterfall(test[dec, ], usd[dec, ], pred[dec], "December 2025: last year's December jump does most of the lifting")

#| **From one month to all months: global importance.** Average the *absolute* SHAP values over the 45 test months. This says how much each feature moves the forecast in a typical month, in dollars, which is easier to explain than "gain".
imp <- colMeans(abs(usd[, features]))    # mean |SHAP| per feature, $ billions
viz_bars(imp, unname(nice[names(imp)]), xlab = "Mean |SHAP|, $ billions",
         title = "Seasonal features move the forecast most; macro drivers barely register",
         subtitle = "Average absolute SHAP value per feature, one-month-ahead forecasts, Jan 2023 to Sep 2026")

#| **Next month's forecast, explained.** In production you refit on all the data you have (through September 2026) and forecast October 2026, the first month nobody has seen. `make_features(retail, extra_month = TRUE)` adds that month's row; its features are all known today.
full <- d[!is.na(d$growth), ]            # every month with a known target
fit_all <- xgb.train(params = params, nrounds = 38,   # same settings, all the data
                     data = xgb.DMatrix(as.matrix(full[, features]), label = full$growth))
nxt <- tail(make_features(retail, extra_month = TRUE), 1)   # the one row for next month
dnext <- xgb.DMatrix(as.matrix(nxt[, features]))
# SHAP values for that row, converted to $ billions, plus the predicted growth
waterfall(nxt, predict(fit_all, dnext, predcontrib = TRUE)[1, ] * nxt$lag1 / 100 / 1000, predict(fit_all, dnext),
          "October 2026: the forecast, and why")
