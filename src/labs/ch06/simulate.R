#| **Simulate four "laboratory" series** of 300 months each. `set.seed()` makes the random draws reproducible, so you get the same numbers as this page.
#| - **White noise**: pure independent shocks, $y_t = \varepsilon_t$.
#| - **AR(1), φ = 0.7**: today keeps 70% of yesterday, $y_t = 0.7\,y_{t-1} + \varepsilon_t$. `arima.sim()` does the recursion for you.
#| - **Random walk**: today = yesterday + shock. A running sum of shocks, so `cumsum()` builds it.
#| - **Random walk with drift**: the same, plus 0.2 every month.
set.seed(2026)                                       # fixed seed: same random numbers every run
n <- 300                                             # length of each simulated series
sims <- list(
  `White noise`     = ts(rnorm(n)),                  # rnorm(n) = n independent standard normal shocks
  `AR(1), phi = 0.7` = arima.sim(model = list(ar = 0.7), n = n),   # simulate y_t = 0.7 y_{t-1} + e_t
  `Random walk`     = ts(cumsum(rnorm(n))),          # running total of shocks
  `RW with drift`   = ts(cumsum(0.2 + rnorm(n)))     # running total of (0.2 + shock)
)

#| **Look first.** The top two hug a fixed level and keep crossing it. The bottom two wander off and never come back on schedule. That visual difference is what *stationary* versus *nonstationary* means.
# sims[[k]] extracts the k-th series from the list; facet = TRUE draws one panel each
viz_ts(`White noise` = sims[[1]], `AR(1), phi = 0.7` = sims[[2]], `Random walk` = sims[[3]], `RW with drift` = sims[[4]],
       facet = TRUE, title = "Two series return to a fixed level; two wander off")

#| **Two unit-root tests with opposite null hypotheses.**
#| - `adf.test()` (augmented Dickey–Fuller): null = **unit root** (nonstationary). A *small* p-value is evidence of stationarity.
#| - `kpss.test()` (KPSS): null = **stationary**. A *small* p-value is evidence of a unit root.
#| Both read p-values off printed tables, so they are capped: ADF never reports below 0.01, KPSS never above 0.10. That is why you see warnings like "p-value smaller than printed p-value".
library(tseries)                                     # adf.test(), kpss.test()
library(forecast)                                    # ndiffs()
# sapply() runs the three tests on each series; t() turns the result into one row per series
tests <- t(sapply(sims, function(x) c(
  `ADF p (H0: unit root)`    = suppressWarnings(adf.test(x)$p.value),    # suppressWarnings hides the capped-p notes
  `KPSS p (H0: stationary)`  = suppressWarnings(kpss.test(x)$p.value),
  `ndiffs()`                 = ndiffs(x))))          # differences needed to reach stationarity
round(tests, 3)

#| **Read the table as a verdict.** When ADF rejects (p < 0.05) *and* KPSS does not reject (p > 0.05), both agree the series is stationary. When it is the other way round, both agree it has a unit root. `ndiffs()` automates this: it applies KPSS repeatedly and returns how many differences you need (0 = already stationary).
viz_table(as.data.frame(tests), digits = 3,
          title = "Tests agree: white noise and AR(1) are stationary, both random walks need one difference")

#| **Difference the random walk once** and test again. `diff(x)` computes $y_t - y_{t-1}$, which for a random walk gives back the white-noise shocks. One difference was enough, exactly as `ndiffs()` predicted.
rw_diff <- diff(sims[["Random walk"]])               # month-to-month changes of the random walk
# rerun both tests and ndiffs() on the differenced series
c(ADF = suppressWarnings(adf.test(rw_diff)$p.value), KPSS = suppressWarnings(kpss.test(rw_diff)$p.value), ndiffs = ndiffs(rw_diff))
