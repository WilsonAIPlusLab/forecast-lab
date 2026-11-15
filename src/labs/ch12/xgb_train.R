#| **Load the target and two macro drivers.** `RSXFSN` is U.S. retail sales excluding food services, **not seasonally adjusted**, in $ millions per month. We also load consumer sentiment and the unemployment rate. We read those two raw files with `read.csv()` on purpose: the unemployment rate has a real hole (October 2025 was never published because of the federal shutdown). `fred()` would fill it by interpolation, which uses *November's* value, information nobody had when forecasting November. That is a small leak, so we keep the hole.
#|
#| *In the browser:* XGBoost's compiled code cannot load in WebAssembly yet, so this page substitutes a pure-R version of the same exact-greedy algorithm and prints a one-line note saying so. In RStudio you get the real package. For the settings in this chapter the numbers are the same; we checked.
library(xgboost)                              # gradient-boosted trees
retail <- fred("RSXFSN", start = 1992)        # monthly retail sales, $ millions, not seasonally adjusted
sent   <- read.csv("data/UMCSENT.csv", na.strings = c(".", ""))   # consumer sentiment index; "." or "" = missing
unemp  <- read.csv("data/UNRATE.csv",  na.strings = c(".", ""))   # unemployment rate, %
names(sent) <- c("date", "sent"); names(unemp) <- c("date", "unrate")   # give the columns simple names

#| **Predict growth, not levels.** Trees can only predict values they have seen in training, so a tree trained on 2010 sales levels can never forecast a record month. Instead we predict this month's **growth over last month, in %**, and turn it back into dollars with *forecast = last month × (1 + growth/100)*. Growth rates look alike in 1995 and 2025, so the trees can learn from all 30 years.
lag_by <- function(x, k) c(rep(NA, k), head(x, -k))   # shift x down k places (NA on top): the lag
d <- data.frame(date = ts_dates(retail), sales = as.numeric(retail))   # one row per month
d$lag1   <- lag_by(d$sales, 1)                # last month's sales
d$growth <- 100 * (d$sales / d$lag1 - 1)      # target: % change from last month

#| **Build the features.** Every feature must be known when the forecast is made, or we leak the future. We forecast each month once last month's sales are published, about two weeks into the month; by then last month's sentiment and unemployment rate are out too:
#| - `month`: calendar month, 1 to 12
#| - `growth_ly`: growth in the same month last year (how big was last December's jump?)
#| - `growth_lm`: last month's growth, and `yoy_lm`: last month's growth over 12 months
#| - `weekend`: number of Saturdays and Sundays in the month (the mix of weekdays and weekend days shifts from year to year)
#| - `sent_lm`, `unrate_lm`: last month's sentiment and unemployment rate
d$month     <- as.integer(substr(d$date, 6, 7))   # characters 6-7 of "YYYY-MM-DD" = the month
d$growth_ly <- lag_by(d$growth, 12)           # same month last year
d$growth_lm <- lag_by(d$growth, 1)            # last month
d$yoy_lm    <- 100 * (d$lag1 / lag_by(d$sales, 13) - 1)   # last month vs 12 months before it, %
# count weekend days: list 31 days from the 1st, keep those in this month, count Saturdays/Sundays ("%u" 6, 7)
d$weekend   <- sapply(as.Date(d$date), function(s) {
  days <- seq(s, by = "day", length.out = 31)
  sum(format(days[format(days, "%m") == format(s, "%m")], "%u") %in% c("6", "7")) })
# merge() joins by date; all.x = TRUE keeps every sales month, even if a macro value is missing
d <- merge(d, data.frame(date = sent$date,  sent_lm   = lag_by(sent$sent, 1)),   all.x = TRUE)
d <- merge(d, data.frame(date = unemp$date, unrate_lm = lag_by(unemp$unrate, 1)), all.x = TRUE)
d <- d[!is.na(d$growth_ly) & !is.na(d$yoy_lm), ]   # drop the first months, which lack a year of history
features <- c("month", "growth_ly", "growth_lm", "yoy_lm", "weekend", "sent_lm", "unrate_lm")   # the 7 predictors
tail(d[, c("date", "growth", features)], 3)   # peek at the last 3 rows

#| **Split by time into three blocks.** We *fit* on 1993–2021, *validate* on 2022 (to decide when to stop adding trees), and keep 2023 onward as the untouched *test* set for Lab 12.2. `xgb.DMatrix()` packs the feature matrix and the label into XGBoost's own format. Missing values (that October 2025 hole) are fine: XGBoost learns which way to send them at every split.
fit_d   <- d[d$date <= "2021-12-01", ]                          # fit block: through 2021
valid_d <- d[d$date >= "2022-01-01" & d$date <= "2022-12-01", ]   # validation block: 2022
dfit   <- xgb.DMatrix(as.matrix(fit_d[, features]),   label = fit_d$growth)     # features + target
dvalid <- xgb.DMatrix(as.matrix(valid_d[, features]), label = valid_d$growth)

#| **Train with early stopping.** The key settings:
#| - `eta` (learning rate): how much of each new tree we add. Small = slow, careful learning.
#| - `max_depth`: how many questions each tree may ask. 3 is plenty for 7 features.
#| - `subsample`: share of rows each tree sees. 0.8 adds helpful randomness; we keep 1 here.
#| - `tree_method = "exact"` tries every possible split. It is fast on 360 rows, and it makes R and Python give *identical* answers.
#| - `nrounds = 1000` is a ceiling. `early_stopping_rounds = 50` stops once the **validation** error has not improved for 50 rounds.
# squared-error loss; nthread = 1 uses one CPU core
params <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 3, subsample = 1, tree_method = "exact", nthread = 1)
boost <- xgb.train(params = params, data = dfit, nrounds = 1000,   # at most 1000 trees
                   evals = list(train = dfit, valid = dvalid),     # track error on both blocks each round
                   early_stopping_rounds = 50, verbose = 0)        # verbose = 0: print nothing while training

#| **Read the learning curve.** Training error keeps falling forever: each new tree fixes more of the training data's quirks. Validation error falls, bottoms out, then drifts up. That turning point is the best number of rounds.
log  <- attributes(boost)$evaluation_log      # table: round number, train RMSE, validation RMSE
best <- which.min(log$valid_rmse)             # round with the lowest validation error
viz_lines(log$iter, Training = log$train_rmse, Validation = log$valid_rmse, xlab = "Boosting round (number of trees)",
          ylab = "RMSE, % points of monthly growth",
          title = sprintf("Validation error bottoms out after %d trees", best),
          subtitle = "Fit on 1993-2021, validated on 2022. Training error keeps falling; validation error does not.")
c(best_round = best, valid_rmse = log$valid_rmse[best])

#| **Refit on everything before the test period.** Now that we know the right number of trees, we retrain on 1993–2022 with exactly that many. The gain importance shows which features the trees split on most profitably.
train <- d[d$date <= "2022-12-01", ]          # fit + validation blocks together: 1993-2022
fit <- xgb.train(params = params, nrounds = best,   # exactly the chosen number of trees
                 data = xgb.DMatrix(as.matrix(train[, features]), label = train$growth))
imp <- xgb.importance(model = fit)            # one row per feature; Gain = share of loss reduction
viz_bars(imp$Gain, imp$Feature, title = "Two seasonal features do most of the work",
         subtitle = "Gain importance: share of the total loss reduction from splits on each feature")
