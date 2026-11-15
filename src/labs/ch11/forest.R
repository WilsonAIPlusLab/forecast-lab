#| **Same table as before:** retail sales growth (% per month, NSA) with lags, the seasonal lag and the calendar month. Train through 2022.
retail <- fred("RSXFSN", start = 2010)        # monthly retail sales, $ millions, not seasonally adjusted
lag_k <- function(x, k) c(rep(NA, k), head(x, -k))   # shift x down k places (NA on top)
make_features <- function(g) {
  x <- as.numeric(g)
  data.frame(date = ts_dates(g), g = x, g1 = lag_k(x, 1), g2 = lag_k(x, 2),   # target g and lags 1, 2
             g12 = lag_k(x, 12), month = factor(cycle(g), levels = 1:12))     # seasonal lag; month as a category
}
train_y <- window(retail, end = c(2022, 12))  # window() cuts a ts by date: levels through Dec 2022
test_y  <- window(retail, start = c(2023, 1)) # test levels: Jan 2023 onward
train   <- na.omit(make_features(100 * diff(log(train_y))))   # growth feature table, incomplete rows dropped

#| **Grow a random forest of 300 trees.** Each tree sees a **bootstrap sample** of the rows (drawn with replacement), and each split considers only `mtry = 2` of the 4 features, chosen at random. The forest's forecast is the average of the 300 trees. `set.seed()` makes the randomness repeatable.
library(randomForest)
set.seed(1)                                   # fix the random numbers so results repeat
rf <- randomForest(g ~ g1 + g2 + g12 + month, data = train,   # predict growth g from 4 features
                   ntree = 300, mtry = 2, importance = TRUE)  # 300 trees; 2 features tried per split; keep importance
rf                                            # summary, including the out-of-bag error

#| **Out-of-bag (OOB) error: a free validation set.** Each bootstrap sample leaves out about a third of the rows. Scoring every row using only the trees that never saw it gives the OOB error that `print(rf)` reports above ("Mean of squared residuals", in squared percentage points). Its square root is a typical miss, in percentage points of monthly growth.
sqrt(tail(rf$mse, 1))                         # rf$mse = OOB MSE after 1, 2, ..., 300 trees; take the last, then sqrt

#| **Which features matter?** *Permutation importance* shuffles one feature at a time in the OOB rows and records how much the OOB mean squared error grows. `scale = FALSE` asks for that raw increase (in squared percentage points); dividing by the OOB MSE turns it into a **% increase in error**. (Beware: the default `importance(rf)` column `%IncMSE` is *not* a percentage. It is the raw increase divided by its standard error, a z-score-like number.) The calendar month and the seasonal lag (`g12`) top the list: shuffling either one multiplies the error several times over, because both encode seasonality. The two recent lags matter less, but they are not useless.
# type = 1: permutation importance; [, 1] takes its single column; then express as % of the OOB MSE
imp <- 100 * importance(rf, type = 1, scale = FALSE)[, 1] / tail(rf$mse, 1)
round(imp)
viz_bars(imp, title = "Seasonality drives the forest's retail forecasts",
         subtitle = "Permutation importance: % increase in OOB mean squared error when the feature is shuffled",
         xlab = "% increase in OOB MSE")

#| **Forecast 2023 onward, recursively, back in dollars.** For each new month: build its one feature row from the history so far (`g1`, `g2`, `g12` and the calendar month, all known before the month starts), predict its growth, turn growth into a level with `last × exp(growth / 100)`, append both, and repeat. Forecasts feed on forecasts, so after a year the forest is predicting from its own predictions.
forecast_rf <- function(model, y, h) {
  lev <- as.numeric(y)                      # levels, $ millions
  g   <- c(NA, 100 * diff(log(lev)))        # growth, aligned with lev
  mon <- as.integer(cycle(y))               # calendar month of each row
  for (k in seq_len(h)) {                   # one pass per month ahead: k = 1, ..., h
    n <- length(lev); m <- mon[n] %% 12 + 1 # the month we are about to forecast
    X <- data.frame(g1 = g[n], g2 = g[n - 1], g12 = g[n - 11], month = factor(m, levels = 1:12))
    g_hat <- predict(model, X)              # forecast growth for month n + 1
    lev <- c(lev, lev[n] * exp(g_hat / 100)); g <- c(g, g_hat); mon <- c(mon, m)   # append as if it were data
  }
  ts(tail(lev, h), start = tsp(y)[2] + 1 / 12, frequency = 12)   # last h levels as a monthly ts after y ends
}
fc_rf <- forecast_rf(rf, train_y, length(test_y))   # forecast every test month

#| **Check it against reality.** The forest reproduces the seasonal shape, including the December peaks, because it learned them from `month` and `g12`. The MAE (in $ millions) goes on the scorecard in the bake-off lab.
viz_compare(history = window(train_y, start = 2019), actual = test_y, `Random forest` = fc_rf,
            title = "The forest learned retail's seasonal rhythm from lag features")
round(mean(abs(test_y - fc_rf)))              # mean absolute error (MAE), $ millions
