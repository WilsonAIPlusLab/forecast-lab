#| **Solution.** `diff(log(x))` turns each trending level into a stationary growth rate, and `scale()` puts every series in standard-deviation units. Now component 1 explains about 46.5% of the movement in five series, and all five load positively: it really is a common "spending" factor.
ids <- c("PCE", "RSFSXMV", "RSMVPD", "TOTALSA", "RSFSDP")   # five monthly, seasonally adjusted series
# 1. Growth rate in % = 100 x change in log (diff takes month-to-month changes)
growth <- lapply(ids, function(id) 100 * diff(log(fred(id, start = 2009))))
panel <- window(do.call(cbind, growth), start = c(2010, 1), end = c(2019, 12))   # 2010-2019: no COVID
colnames(panel) <- ids                                  # name each column after its FRED ID

# 2. Standardize: subtract each column's mean, divide by its standard deviation
Z <- scale(panel)
pc <- prcomp(Z)                                         # principal components of the standardized panel
share <- pc$sdev^2 / sum(pc$sdev^2)                     # share of total variance per component
w <- pc$rotation[, 1]                                   # loadings (weights) of component 1
if (w["PCE"] < 0) w <- -w                               # sign is arbitrary: make spending load positively
round(share, 3)                                         # read the first number as "% of variance explained"
round(w, 2)                                             # every series should carry real weight
