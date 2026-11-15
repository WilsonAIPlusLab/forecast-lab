#| **Same data, same split as the Chapter 3 scorecard:** retail sales (RSXFSN, $ millions, NSA) from 2010, trained through December 2022, tested on every month from January 2023.
library(forecast); library(randomForest)
retail  <- fred("RSXFSN", start = 2010)
train_y <- window(retail, end = c(2022, 12))
test_y  <- window(retail, start = c(2023, 1))
h       <- length(test_y)

#| **The statistical contestants.** Seasonal naive is the benchmark to beat. `ets()` picks an exponential-smoothing model automatically (Chapter 5).
f_snaive <- snaive(train_y, h = h)$mean
f_ets    <- forecast(ets(train_y), h = h)$mean

#| **The forest from the previous lab**, rebuilt exactly (same features, same seed, same settings), plus its recursive forecaster.
lag_k <- function(x, k) c(rep(NA, k), head(x, -k))
make_features <- function(g) {
  x <- as.numeric(g)
  data.frame(date = ts_dates(g), g = x, g1 = lag_k(x, 1), g2 = lag_k(x, 2),
             g12 = lag_k(x, 12), month = factor(cycle(g), levels = 1:12))
}
forecast_rf <- function(model, y, h) {
  lev <- as.numeric(y)                      # levels, $ millions
  g   <- c(NA, 100 * diff(log(lev)))        # growth, aligned with lev
  mon <- as.integer(cycle(y))               # calendar month of each row
  for (k in seq_len(h)) {
    n <- length(lev); m <- mon[n] %% 12 + 1 # the month we are about to forecast
    X <- data.frame(g1 = g[n], g2 = g[n - 1], g12 = g[n - 11], month = factor(m, levels = 1:12))
    g_hat <- predict(model, X)              # forecast growth for month n + 1
    lev <- c(lev, lev[n] * exp(g_hat / 100)); g <- c(g, g_hat); mon <- c(mon, m)
  }
  ts(tail(lev, h), start = tsp(y)[2] + 1 / 12, frequency = 12)
}
train <- na.omit(make_features(100 * diff(log(train_y))))
set.seed(1)
rf <- randomForest(g ~ g1 + g2 + g12 + month, data = train, ntree = 300, mtry = 2, importance = TRUE)
f_rf <- forecast_rf(rf, train_y, h)

#| **A cautionary contestant: the same forest on levels.** Swap the growth target for dollar levels (lags of the level, plus month). Watch what the extrapolation trap does to it.
lev <- as.numeric(train_y)
lev_tab <- na.omit(data.frame(y = lev, l1 = lag_k(lev, 1), l2 = lag_k(lev, 2), l12 = lag_k(lev, 12),
                              month = factor(cycle(train_y), levels = 1:12)))
set.seed(1)
rf_lev <- randomForest(y ~ ., data = lev_tab, ntree = 300, mtry = 2)
hist <- lev; mon <- as.integer(cycle(test_y))
for (k in 1:h) {
  n <- length(hist)
  hist <- c(hist, predict(rf_lev, data.frame(l1 = hist[n], l2 = hist[n - 1], l12 = hist[n - 11],
                                             month = factor(mon[k], levels = 1:12))))
}
f_rf_lev <- ts(tail(hist, h), start = c(2023, 1), frequency = 12)

#| **Score everyone on the same test months.** MASE divides MAE by the in-sample MAE of seasonal naive, as in Chapter 3: below 1 beats that benchmark.
scale <- mean(abs(diff(train_y, lag = 12)))
score <- function(f) { e <- test_y - f
  c(ME = mean(e), MAE = mean(abs(e)), RMSE = sqrt(mean(e^2)), MAPE = 100 * mean(abs(e / test_y)), MASE = mean(abs(e)) / scale) }
board <- rbind(`Seasonal naive` = score(f_snaive), ETS = score(f_ets),
               `Random forest (levels)` = score(f_rf_lev), `Random forest (growth)` = score(f_rf),
               `ETS + forest average` = score((f_ets + f_rf) / 2))
round(board, 2)

#| **The scorecard.** Green marks the best value in each column. Read it honestly: which row wins on MAE, and by how much? Look at the **ME** (bias) column too: ETS over-forecasts and the forest under-forecasts, by similar amounts. That is why the last row, a simple 50/50 average of the two (forecast combination, Chapter 10), does better than either.
viz_table(board, highlight = c("MAE", "RMSE", "MAPE", "MASE"), digits = 2,
          title = "ML vs ETS bake-off: retail sales, test period 2023 onward")
viz_compare(history = window(train_y, start = 2020), actual = test_y,
            `Seasonal naive` = f_snaive, ETS = f_ets, `Random forest` = f_rf,
            title = "ETS and the growth forest both track the seasonal pattern")

#| **Is the forest's score luck?** A random forest is random. Re-grow it with four more seeds and re-score. ETS gives the same answer every time; the forest's MAE moves around. Compare the spread with the ETS row above before declaring a winner.
mae_by_seed <- sapply(2:5, function(s) {
  set.seed(s)
  m <- randomForest(g ~ g1 + g2 + g12 + month, data = train, ntree = 300, mtry = 2, importance = TRUE)
  mean(abs(test_y - forecast_rf(m, train_y, h)))
})
round(c(seed_1 = board["Random forest (growth)", "MAE"], setNames(mae_by_seed, paste0("seed_", 2:5)),
        ETS = board["ETS", "MAE"]))
