#| **Load the two series.** `fred("ICSA", to = "month")` averages the four or five weekly readings of initial jobless claims in each month. `PAYEMS` is total nonfarm payroll employment in thousands. Both are seasonally adjusted, so a rise is a real rise, not a holiday effect.
claims <- fred("ICSA", to = "month")   # initial claims, monthly average of weekly data, SA
jobs   <- fred("PAYEMS")               # nonfarm payrolls, thousands, SA

#| **Put both on the same footing: growth over the past year.** `100 * diff(log(x), lag = 12)` is close to the percent change from the same month a year earlier. We keep 1990 to 2019 so that COVID, which moved claims by more than 1,000% in a few weeks, does not swamp everything. We come back to it later.
claims_yoy <- window(100 * diff(log(claims), lag = 12), start = c(1990, 1), end = c(2019, 12))
jobs_yoy   <- window(100 * diff(log(jobs),   lag = 12), start = c(1990, 1), end = c(2019, 12))

#| **The cross-correlation function.** `ccf(x, y)` at lag *k* is the correlation between `x[t + k]` and `y[t]`. So a **negative** *k* means *x* moved first: it **leads** *y*. We ask for lags from −18 to +18 months and find the one with the strongest correlation, positive or negative.
cc <- ccf(as.numeric(claims_yoy), as.numeric(jobs_yoy), lag.max = 18, plot = FALSE)
r  <- setNames(as.numeric(cc$acf), as.numeric(cc$lag))
best <- as.numeric(names(which.max(abs(r))))
round(c(best_lag = best, corr_at_best = r[[as.character(best)]], corr_same_month = r[["0"]]), 2)

#| **Chart the cross-correlations.** Bars outside the shaded band (±1.96/√n) would be "significant" if the data had no autocorrelation. Both series are very smooth, so treat the band as a rough guide only: the *shape* matters more. Notice the asymmetry: the correlations on the left (claims first) are much stronger than on the right.
viz_custom("ch07-ccf", lag = as.numeric(cc$lag), value = r, ci = 1.96 / sqrt(length(jobs_yoy)), best = best,
           xlab = "lag k (months); negative = claims move first", title = "Claims growth peaks about 7 months before job growth does",
           source = "FRED (ICSA, PAYEMS)")

#| **See the lead with your own eyes.** We standardize both series (subtract the mean, divide by the standard deviation), flip the sign of claims so both rise in good times, and shift claims *later* by the lead we found. `stats::lag(x, k = -7)` moves a series 7 months to the right. The two lines now rise and fall almost together.
lead <- -best
z <- function(x) (x - mean(x)) / sd(x)
viz_ts(`Job growth (yoy, standardized)` = z(jobs_yoy),
       `Claims growth, inverted, shifted 7 months later` = stats::lag(-z(claims_yoy), k = -lead),
       title = "Shift claims forward and they trace the path of job growth", recessions = TRUE)
