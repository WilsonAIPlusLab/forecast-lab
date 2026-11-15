#| **Build the forecasting table.** Target: jobs added in month *t* (`dj`). Predictors must be **known when the forecast is made**. Standing at the end of month *t − 1*, you know `dj` for *t − 1* and *t − 2*, and claims growth through *t − 1* (`dcl1`). Same-month claims (`dcl0`) are only complete about when the jobs report itself comes out, so a model with `dcl0` is a **nowcast**, not a forecast. Calling a nowcast a forecast is look-ahead leakage.
library(forecast)                                    # dm.test()
claims <- fred("ICSA", to = "month"); jobs <- fred("PAYEMS")   # initial claims (monthly avg) and payrolls, SA
dj <- diff(jobs); dcl <- 100 * diff(log(claims))     # jobs added (thousands); % change in claims
# stats::lag(x, -1) shifts a series one month later, so row t holds the value from t - 1
X  <- window(ts.intersect(dj, dj1 = stats::lag(dj, -1), dj2 = stats::lag(dj, -2),
                          dcl1 = stats::lag(dcl, -1), dcl0 = dcl), start = c(1990, 1))
tt    <- as.numeric(time(X))                         # decimal dates, e.g. 2020.167 = March 2020
covid <- tt > 2020.1 & tt < 2022                     # March 2020 to December 2021

#| **A pseudo out-of-sample loop.** For each target month *i* we fit the model on all months *before* it (an expanding window), forecast month *i*, and keep the error. `lm.fit()` is the engine inside `lm()`: same OLS estimates, without the formula overhead, so hundreds of refits stay fast in your browser. An AR(2) fitted by OLS is the conditional version of `Arima(order = c(2, 0, 0))`. Optionally we drop the COVID months from the training data.
oos <- function(vars, from, to, drop_covid = FALSE) {
  Z <- cbind(1, X[, vars, drop = FALSE]); y <- X[, "dj"]   # Z = intercept column + chosen predictors
  sapply(which(tt >= from - 1e-6 & tt <= to + 1e-6), function(i) {   # each target month in the test window
    train <- seq_len(i - 1)                          # rows 1 .. i-1: everything before month i
    if (drop_covid) train <- train[!covid[train]]    # optionally remove pandemic months
    b <- lm.fit(Z[train, , drop = FALSE], y[train])$coefficients   # OLS on the training rows
    y[i] - sum(Z[i, ] * b)                           # forecast error: actual minus prediction
  })
}
models <- list(AR = c("dj1", "dj2"),                              # benchmark: AR(2)
               `AR + claims(t-1)` = c("dj1", "dj2", "dcl1"),       # a real forecast
               `AR + claims(t) nowcast` = c("dj1", "dj2", "dcl0")) # a nowcast

#| **Run it in four test windows**: a calm decade (2010–2019), the Great Recession (2007–2010), and the post-COVID years (2022 to the latest data), first with the pandemic months left in the training data and then with them dropped.
end <- max(tt)                                       # latest month in the data
# each window = c(first month, last month, drop COVID? 1 = yes); 11/12 = December as a decimal
windows <- list(`Calm 2010–19` = c(2010, 2019 + 11/12, 0), `Recession 2007–10` = c(2007, 2010 + 11/12, 0),
                `2022+, COVID in training` = c(2022, end, 0), `2022+, COVID dropped` = c(2022, end, 1))
errs <- lapply(windows, function(w) lapply(models, function(v) oos(v, w[1], w[2], drop_covid = w[3] == 1)))   # errors per window, per model
rmse <- function(e) sqrt(mean(e^2))                  # root mean squared error
score <- sapply(errs, function(e) sapply(e, rmse))     # rows = models, columns = test windows
round(score, 1)

#| **Is the improvement real?** The Diebold–Mariano test (Chapter 3) compares the AR's errors with each claims model's. A small p-value means the accuracy gap is unlikely to be luck.
# e[[1]] = AR errors, e[[2]] = claims(t-1) errors, e[[3]] = nowcast errors; h = 1 for one-step forecasts
dm_p <- sapply(errs, function(e) c(`claims(t-1) vs AR` = unname(dm.test(e[[1]], e[[2]], h = 1)$p.value),
                                   `nowcast vs AR`     = unname(dm.test(e[[1]], e[[3]], h = 1)$p.value)))
round(dm_p, 3)

#| **The scorecard.** One-month-ahead RMSE in thousands of jobs; green marks the best model in each test window. Read it column by column, and be honest about what it says.
viz_table(score, highlight = names(windows), digits = 1,   # highlight the lowest RMSE in every column
          title = "Claims help most as a nowcast in a downturn; COVID data poison the fit")
