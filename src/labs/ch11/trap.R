#| **A steadily trending series.** U.S. e-commerce sales (MRTSSM4541USS, $ millions, **seasonally adjusted**). Train through December 2022, then forecast every month from January 2023 onward. Note the training maximum: no month before 2023 was higher.
ecom  <- fred("MRTSSM4541USS", start = 2010)  # monthly e-commerce sales, $ millions, seasonally adjusted
train <- window(ecom, end = c(2022, 12))      # training set: through Dec 2022
test  <- window(ecom, start = c(2023, 1))     # test set: Jan 2023 onward
h     <- length(test)                         # forecast horizon = number of test months
max(train)                                    # the highest month the models will ever see

#| **A lag table and a recursive forecaster.** `lag_table()` turns any vector into rows of (target, lag1, lag2, lag3). `recursive()` forecasts one month, appends that forecast to the history as if it were data, and repeats `h` times: the **recursive** multi-step strategy.
lag_table <- function(x) {
  x <- as.numeric(x); n <- length(x)
  # row t: target x[t] and the three values before it (rows start at t = 4)
  data.frame(y = x[4:n], lag1 = x[3:(n - 1)], lag2 = x[2:(n - 2)], lag3 = x[1:(n - 3)])
}
recursive <- function(model, history, h) {
  history <- as.numeric(history)
  for (k in 1:h) {                            # one pass per month ahead
    n <- length(history)
    new <- data.frame(lag1 = history[n], lag2 = history[n - 1], lag3 = history[n - 2])   # last 3 values
    history <- c(history, predict(model, new))   # append the forecast as if it were data
  }
  tail(history, h)                            # return only the h forecasts
}

#| **Forest 1: forecast the level directly.** A random forest of 200 trees learns "next month's sales given the last three months". Predict first: what will its forecasts look like once sales climb above anything it saw in training?
library(randomForest)
set.seed(11)                                  # fix the random numbers so results repeat
rf_level <- randomForest(y ~ ., data = lag_table(train), ntree = 200)   # y ~ . means "use every other column"
fc_level <- recursive(rf_level, train, h)     # forecast dollar levels for every test month
round(range(fc_level))                        # lowest and highest forecast

#| **The trap, in numbers.** Every forecast sits *below* the training maximum, even though actual sales kept rising. A tree's forecast is an average of training targets, so it can never exceed the largest one. A forest averages trees, so it inherits the same ceiling.
c(training_max = max(train), highest_forecast = round(max(fc_level)), highest_actual = max(test))

#| **Forest 2: forecast the growth rate instead.** Same features, same settings, but the target is monthly % growth, which stays inside a familiar range even while the level climbs. To get back to dollars, compound the forecast growth rates from the last observed level: `last × exp(cumsum(growth / 100))`.
gr <- 100 * diff(log(train))                  # monthly growth, %
set.seed(11)                                  # same seed as forest 1
rf_growth <- randomForest(y ~ ., data = lag_table(gr), ntree = 200)
fc_g      <- recursive(rf_growth, gr, h)      # forecast growth rates
fc_growth <- as.numeric(tail(train, 1)) * exp(cumsum(fc_g) / 100)   # compound from the last level; cumsum = running total

#| **Compare both against what happened.** The level forest flat-lines under its ceiling; the growth forest keeps climbing.
as_ts <- function(v) ts(v, start = start(test), frequency = 12)   # helper: date a vector like the test set
viz_compare(history = window(train, start = 2018), actual = test,
            `Forest on levels` = as_ts(fc_level), `Forest on growth` = as_ts(fc_growth),
            title = "A forest trained on levels cannot forecast above its training maximum")
mae <- function(f) mean(abs(test - f))        # mean absolute error, $ millions
round(c(levels = mae(fc_level), growth = mae(fc_growth)))

#| **Two more ways out: differences and detrending.** Any target that stays inside its training range works. *Differences*: forecast the dollar change, then add the changes up from the last level. *Detrending*: fit a straight line to log sales (a constant growth trend), let the forest forecast the gap from that line, then add the line back and undo the log with `exp()`. All three fixes land far below the level forest's error.
dd <- diff(train)                             # monthly change, $ millions
set.seed(11)
rf_diff <- randomForest(y ~ ., data = lag_table(dd), ntree = 200)
fc_diff <- as.numeric(tail(train, 1)) + cumsum(recursive(rf_diff, dd, h))   # last level + running total of changes
tt  <- seq_along(train)                       # time index 1, 2, ..., n
trend <- lm(log(as.numeric(train)) ~ tt)      # log-linear trend: log sales = a + b * t
gap <- residuals(trend)                       # how far each month sits above (+) or below (-) the trend line
set.seed(11)
rf_gap <- randomForest(y ~ ., data = lag_table(gap), ntree = 200)
line_ahead <- predict(trend, data.frame(tt = length(train) + 1:h))   # the trend line extended h months
fc_detr <- exp(line_ahead + recursive(rf_gap, gap, h))   # trend + forecast gap, back from logs to dollars
round(c(levels = mae(fc_level), growth = mae(fc_growth), differences = mae(fc_diff), detrended = mae(fc_detr)))
