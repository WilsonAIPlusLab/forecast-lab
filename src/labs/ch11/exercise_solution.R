library(randomForest)
starts  <- fred("HOUST", start = 2010)    # housing starts, thousands of units (SAAR)
permits <- fred("PERMIT", start = 2010)   # building permits, thousands of units (SAAR)
permits <- window(permits, end = end(starts))
lag_k <- function(x, k) c(rep(NA, k), head(x, -k))

# The table: target g = growth of starts (%), with lags, as in the chapter
g <- c(NA, 100 * diff(log(starts)))
d <- data.frame(date = ts_dates(starts), level = as.numeric(starts), prev = lag_k(as.numeric(starts), 1),
                g = g, g1 = lag_k(g, 1), g2 = lag_k(g, 2), g12 = lag_k(g, 12))

# 1. NEW FEATURE: last month's permits-to-starts gap, in log % (known before this month's starts are out)
d$gap1 <- lag_k(100 * log(as.numeric(permits) / as.numeric(starts)), 1)

train <- na.omit(d[d$date <  "2023-01-01", ])
test  <- d[d$date >= "2023-01-01", ]

# 2. Fit the forest without and with the new feature (same seed, same settings)
set.seed(1); rf_base <- randomForest(g ~ g1 + g2 + g12, data = train, ntree = 300, mtry = 2)
set.seed(1); rf_plus <- randomForest(g ~ g1 + g2 + g12 + gap1, data = train, ntree = 300, mtry = 2)

# One-step-ahead test MAE, back in thousands of units: last month's level x exp(growth forecast)
mae <- function(model) mean(abs(test$level - test$prev * exp(predict(model, test) / 100)))
mae_base <- mae(rf_base)
mae_plus <- mae(rf_plus)
round(c(base = mae_base, with_gap = mae_plus), 1)
