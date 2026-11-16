library(randomForest)
retail <- fred("RSXFSN", start = 2010)        # monthly retail sales, $ millions, not seasonally adjusted
g <- 100 * diff(log(retail)); x <- as.numeric(g)   # monthly growth, % (the target), as a plain vector
lag_k <- function(x, k) c(rep(NA, k), head(x, -k))   # shift x down k places (NA on top)
d <- data.frame(date = ts_dates(g), g = x, g1 = lag_k(x, 1), g2 = lag_k(x, 2),   # target and lags 1, 2
                g12 = lag_k(x, 12), month = factor(cycle(g), levels = 1:12))     # seasonal lag; month as a category
train <- na.omit(d[d$date <  "2023-01-01", ])   # training rows: before 2023
test  <- d[d$date >= "2023-01-01", ]            # test rows: 2023 onward

# Permutation importance as a % increase in OOB mean squared error (as in the forest lab)
imp_pct <- function(rf) round(100 * importance(rf, type = 1, scale = FALSE)[, 1] / tail(rf$mse, 1))
mae     <- function(rf) round(mean(abs(test$g - predict(rf, test))), 2)   # test MAE, pp of monthly growth

# The manager's chart: all four features
set.seed(1); rf_full <- randomForest(g ~ g1 + g2 + g12 + month, data = train, ntree = 300, mtry = 2, importance = TRUE)

# 1. Drop the calendar month: keep the two recent lags and the seasonal lag
set.seed(1); rf_small <- randomForest(g ~ g1 + g2 + g12, data = train, ntree = 300, mtry = 2, importance = TRUE)

# 2. Importance in the smaller forest, then compare both models side by side
imp_full  <- imp_pct(rf_full)                 # % increase in OOB MSE, full model
imp_small <- imp_pct(rf_small)                # same, without month
imp_full; imp_small
c(full = mae(rf_full), without_month = mae(rf_small))   # did accuracy really suffer?
