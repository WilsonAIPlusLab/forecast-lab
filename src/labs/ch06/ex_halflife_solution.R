library(forecast)                                      # Arima()
s <- fred("UMCSENT", start = 1990, end = c(2019, 12))  # consumer sentiment index (1966:Q1 = 100), monthly

# 1. Fit an AR(1) with a mean: (s_t - mean) = phi * (s_{t-1} - mean) + shock
fit <- Arima(s, order = c(1, 0, 0), include.mean = TRUE)   # p = 1: one lag of the series, no differencing
phi <- unname(coef(fit)["ar1"])                        # persistence: share of a gap that survives one month
phi

# 2. Half-life: months until half of a shock has faded
half_life <- log(0.5) / log(phi)                       # solves phi^h = 0.5 for h
half_life

# 3. Scenario: a shock leaves sentiment 10 points below its average
gap12 <- 10 * phi^12                                   # expected gap after 12 months, in index points
gap12
