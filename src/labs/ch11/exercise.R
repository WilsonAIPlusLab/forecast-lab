library(randomForest)
starts  <- fred("HOUST", start = 2010)    # housing starts, thousands of units (SAAR)
permits <- fred("PERMIT", start = 2010)   # building permits, thousands of units (SAAR)
permits <- window(permits, end = end(starts))   # trim permits so both series end in the same month
lag_k <- function(x, k) c(rep(NA, k), head(x, -k))   # shift x down k places (NA on top)

# The table: target g = growth of starts (%), with lags, as in the chapter
g <- c(NA, 100 * diff(log(starts)))       # monthly growth of starts, %; NA keeps it aligned with the dates
# level = this month's starts, prev = last month's starts, then target g and its lags 1, 2, 12
d <- data.frame(date = ts_dates(starts), level = as.numeric(starts), prev = lag_k(as.numeric(starts), 1),
                g = g, g1 = lag_k(g, 1), g2 = lag_k(g, 2), g12 = lag_k(g, 12))

# 1. NEW FEATURE: last month's permits-to-starts gap, in log % (known before this month's starts are out)
# blank: the series that goes on top of the ratio (the paperwork that comes before a start)
d$gap1 <- lag_k(100 * log(as.numeric(______) / as.numeric(starts)), 1)

train <- na.omit(d[d$date <  "2023-01-01", ])   # training rows: before 2023, no missing values
test  <- d[d$date >= "2023-01-01", ]            # test rows: 2023 onward

# 2. Fit the forest without and with the new feature (same seed, same settings)
set.seed(1); rf_base <- randomForest(g ~ g1 + g2 + g12, data = train, ntree = 300, mtry = 2)
# blank: the name of the column you created in step 1
set.seed(1); rf_plus <- randomForest(g ~ g1 + g2 + g12 + ______, data = train, ntree = 300, mtry = 2)

# One-step-ahead test MAE, back in thousands of units: last month's level x exp(growth forecast)
mae <- function(model) mean(abs(test$level - test$prev * exp(predict(model, test) / 100)))
mae_base <- mae(rf_base)                  # error without the new feature
mae_plus <- mae(rf_plus)                  # error with it: lower is better
round(c(base = mae_base, with_gap = mae_plus), 1)
