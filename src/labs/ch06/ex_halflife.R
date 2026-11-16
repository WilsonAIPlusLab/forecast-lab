library(forecast)                                      # Arima()
s <- fred("UMCSENT", start = 1990, end = c(2019, 12))  # consumer sentiment index (1966:Q1 = 100), monthly

# 1. Fit an AR(1) with a mean: (s_t - mean) = phi * (s_{t-1} - mean) + shock
# Blank: the AR order p for an AR(1)
fit <- Arima(s, order = c(______, 0, 0), include.mean = TRUE)
phi <- unname(coef(fit)["ar1"])                        # persistence: share of a gap that survives one month
phi

# 2. Half-life: months until half of a shock has faded, log(0.5) / log(phi)
# Blank: the share of the shock that is left at the half-life
half_life <- log(______) / log(phi)
half_life

# 3. Scenario: a shock leaves sentiment 10 points below its average.
#    Expected gap 12 months later = 10 * phi^12
# Blank: the number of months
gap12 <- 10 * phi^______
gap12
