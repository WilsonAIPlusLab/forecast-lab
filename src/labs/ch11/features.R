#| **Start from a series, not a spreadsheet.** Retail sales (RSXFSN, $ millions, **not** seasonally adjusted) from 2010. We will forecast its **monthly growth rate** in percent: `100 * diff(log(retail))` is, to a close approximation, the % change from last month. (The extrapolation-trap section explains why we forecast growth rather than the level.)
retail <- fred("RSXFSN", start = 2010)        # monthly U.S. retail sales ($ millions, not seasonally adjusted)
g <- 100 * diff(log(retail))                  # monthly growth in %: difference of logs, times 100
round(tail(g, 13), 1)                         # show the last 13 months of growth, 1 decimal

#| **A lag in one line.** `lag_k(x, k)` slides a vector down `k` rows and pads the top with `NA`. After it, row *t* holds the value from *t − k*: exactly what you knew `k` months earlier.
# helper: shift x down k places; head(x, -k) drops the last k values, NA fills the top
lag_k <- function(x, k) c(rep(NA, k), head(x, -k))
lag_k(1:6, 2)                                 # try it: NA NA 1 2 3 4

#| **Build the supervised-learning table.** One row per month. The **target** is this month's growth `g`. Every **feature** is something you would already know *before* the month starts:
#| - `g1`, `g2`: growth one and two months ago
#| - `g12`: growth in the same month last year (the seasonal lag)
#| - `roll3`: the average of the last three months, a window that **ends at t − 1**
#| - `month`: the calendar month, as a category
#| - `trend`: a running count of months
make_features <- function(g) {
  x <- as.numeric(g)                          # drop the ts wrapper: a plain vector of growth rates
  data.frame(date  = ts_dates(g), g = x,      # one row per month; g = target
             g1 = lag_k(x, 1), g2 = lag_k(x, 2), g12 = lag_k(x, 12),   # lags 1, 2 and 12 months
             roll3 = (lag_k(x, 1) + lag_k(x, 2) + lag_k(x, 3)) / 3,   # mean of the 3 previous months
             month = factor(cycle(g), levels = 1:12),   # cycle() gives the month 1-12; factor = category
             trend = seq_along(x))            # 1, 2, 3, ...: a running month counter
}
feats <- make_features(g)                     # the full feature table
tail(feats, 4)                                # look at the last 4 rows

#| **A leakage test.** Here is the most common feature-engineering mistake: a rolling mean whose window *includes* this month, `(g + g1 + g2) / 3`. It looks harmless, but it contains the answer. A plain regression on it plus the two lags explains **100%** of the target (R² = 1; R even warns you about an "essentially perfect fit"), because `g = 3 × leaky_roll3 − g1 − g2`. That "skill" vanishes the day you forecast for real: this month's value isn't known yet.
feats$leaky_roll3 <- (feats$g + feats$g1 + feats$g2) / 3   # WRONG on purpose: window includes this month
# R-squared of a linear regression (lm) with the honest feature vs the leaky one
round(c(honest = summary(lm(g ~ g1 + g2 + roll3, feats))$r.squared,
        leaky  = summary(lm(g ~ g1 + g2 + leaky_roll3, feats))$r.squared), 3)
feats$leaky_roll3 <- NULL   # delete it so it can never sneak into a model

#| **Split by time, then drop incomplete rows.** The first 12 rows have no `g12` (there is no "last year" yet), so `na.omit()` drops them from training. Training ends in December 2022; the test set is 2023 onward, the same split as the course scorecard in Chapter 3.
train <- na.omit(feats[feats$date <  "2023-01-01", ])   # df[rows, ]: keep rows before 2023, drop rows with NA
test  <- feats[feats$date >= "2023-01-01", ]            # 2023 onward: the test set
c(train_rows = nrow(train), test_rows = nrow(test))     # how many months in each

#| **The finished table.** This is what every machine-learning model in this chapter and the next actually sees: no dates, no "time series", just rows of features and a target. Notice the strong December (`month = 12`) and January rows.
viz_table(tail(train[, c("date", "month", "g12", "g2", "g1", "roll3", "g")], 8), digits = 1,   # last 8 training rows
          title = "A time series, rebuilt as a supervised-learning table")
