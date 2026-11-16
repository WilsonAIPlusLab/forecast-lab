library(randomForest)
retail <- fred("RSXFSN", start = 2010)        # monthly retail sales, $ millions, not seasonally adjusted
g  <- 100 * diff(log(retail))                 # monthly growth, % (the target)
x  <- as.numeric(g)                           # plain vector of growth rates
lag_k <- function(x, k) c(rep(NA, k), head(x, -k))   # shift x down k places (NA on top)

# Your colleague's rolling mean: filter(..., sides = 1) averages months t-2, t-1 AND t (this month!)
roll3_colleague <- as.numeric(stats::filter(x, rep(1/3, 3), sides = 1))

d <- data.frame(date = ts_dates(g), g = x, g1 = lag_k(x, 1), g2 = lag_k(x, 2),   # target and two lags
                roll3_leaky = roll3_colleague)                                   # the colleague's feature

# 1. FIX: shift the colleague's mean down one row, so the window is t-3, t-2, t-1 (all known before month t)
d$roll3 <- lag_k(roll3_colleague, 1)

train <- na.omit(d[d$date <  "2023-01-01", ])   # training rows: before 2023, no missing values
test  <- d[d$date >= "2023-01-01", ]            # test rows: 2023 onward

# Same forest settings and seed for both, so only the rolling feature differs
set.seed(1); rf_leaky  <- randomForest(g ~ g1 + g2 + roll3_leaky, data = train, ntree = 300, mtry = 2)
set.seed(1); rf_honest <- randomForest(g ~ g1 + g2 + roll3,       data = train, ntree = 300, mtry = 2)

# 2. Test MAE in percentage points of monthly growth: actual growth minus the forecast
mae <- function(model) mean(abs(test$g - predict(model, test)))
mae_leaky  <- mae(rf_leaky)                   # looks great, but uses this month's value
mae_honest <- mae(rf_honest)                  # what you could really achieve
round(c(leaky = mae_leaky, honest = mae_honest), 2)
