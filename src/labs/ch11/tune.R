#| **Tune on the past only.** We must choose the forest's settings *without* touching the 2023+ test months. So we stay inside the training data (2010–2022) and run time-series cross-validation, as in Chapter 3.
library(forecast); library(randomForest)
retail  <- fred("RSXFSN", start = 2010)
train_y <- window(retail, end = c(2022, 12))

#| **Helpers from the forest lab**: the feature table and the recursive forecaster.
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

#| **Rolling origins.** Stand at the end of each December from 2017 to 2021, train on everything up to that point, forecast the next 12 months, and record the absolute errors. Five origins, five honest "test years" (2018 to 2022), all inside the training period.
origins <- 2017:2021
cv_mae <- function(fit_fun) {
  errs <- c()
  for (yr in origins) {
    y_tr <- window(train_y, end = c(yr, 12))
    y_te <- window(train_y, start = c(yr + 1, 1), end = c(yr + 1, 12))
    errs <- c(errs, abs(y_te - fit_fun(y_tr)))
  }
  mean(errs)
}

#| **The tuning grid.** `mtry` is how many of the 4 features each split may consider (`mtry = 4` means no feature sampling at all: plain bagging). `nodesize` is the smallest allowed leaf: bigger leaves mean smoother, less wiggly trees. 6 combinations × 5 origins = 30 small forests (100 trees each, to keep it quick).
grid <- expand.grid(mtry = c(1, 2, 4), nodesize = c(5, 20))
grid$cv_MAE <- sapply(seq_len(nrow(grid)), function(i) cv_mae(function(y) {
  set.seed(1)
  m <- randomForest(g ~ g1 + g2 + g12 + month, data = na.omit(make_features(100 * diff(log(y)))),
                    ntree = 100, mtry = grid$mtry[i], nodesize = grid$nodesize[i])
  forecast_rf(m, y, 12)
}))
grid[order(grid$cv_MAE), ]

#| **Put the statistical models through the same test.** Same five origins, same 12-month horizon. (To keep this fast, ETS is fixed at the ETS(M,A,M) form that `ets()` picks on the full training data.)
cv_ets    <- cv_mae(function(y) forecast(ets(y, model = "MAM", damped = FALSE), h = 12)$mean)
cv_snaive <- cv_mae(function(y) snaive(y, h = 12)$mean)
best <- grid[which.min(grid$cv_MAE), ]
cv_board <- data.frame(Model = c(sprintf("Random forest (mtry = %d, nodesize = %d)", best$mtry, best$nodesize), "ETS(M,A,M)", "Seasonal naive"),
                       `CV MAE` = c(best$cv_MAE, cv_ets, cv_snaive), check.names = FALSE)
viz_table(cv_board, highlight = "CV MAE", digits = 0,
          title = "Over five rolling years, ETS beats the best-tuned forest")
cv_board
