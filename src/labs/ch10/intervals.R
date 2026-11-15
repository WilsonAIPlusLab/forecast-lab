#| **Stand in December 2019.** We train on retail sales from 2010 through 2019 (`RSXFSN`, $ millions, monthly, **not** seasonally adjusted) and keep 2020–2021 aside as "what really happened". Nobody in December 2019 knew a pandemic was coming, so this is an honest test of how wide our uncertainty should have been.
library(forecast)                             # ets(), forecast(), simulate()
retail <- fred("RSXFSN", start = 2010)        # monthly U.S. retail sales, $ millions, not seasonally adjusted
train  <- window(retail, end = c(2019, 12))   # training set: up to December 2019
actual <- window(retail, start = c(2020, 1), end = c(2021, 12))   # what really happened, 2020-2021 (24 months)
fit <- ets(train)                             # let ets() pick the best exponential smoothing model
fit$method                                    # which model it chose, e.g. ETS(M,Ad,M)

#| **Way 1: the formula.** `forecast()` turns the model's error variance into intervals. Each step ahead adds new shocks on top of the old ones, so the variance grows with the horizon $h$ and the fan widens. For a multiplicative ETS model these intervals are approximations; for additive models they are exact *if* the errors are normal and the model is right.
fc_formula <- forecast(fit, h = 24, level = c(80, 95))   # 24 months ahead with 80% and 95% intervals
viz_forecast(fc_formula, actual = actual, from = 2016,   # show history from 2016 plus the real 2020-21 data
             title = "The 95% fan from December 2019 missed the pandemic",
             ylab = "$ millions")

#| **Way 2: bootstrapped residuals.** Instead of assuming normal errors, `bootstrap = TRUE` re-uses the model's own past one-step errors, drawn at random with replacement. If past errors were skewed or fat-tailed, the intervals inherit that shape.
set.seed(2026)                                # fix the random draws so results repeat exactly
# intervals from 2,000 resampled paths
fc_boot <- forecast(fit, h = 24, level = c(80, 95), bootstrap = TRUE, npaths = 2000)

#| **Way 3: simulate whole future paths.** `simulate(fit, nsim = 24, future = TRUE)` draws one possible 24-month future from the fitted model, shock by shock. `replicate()` repeats that 50 times. Each column of `paths` is one plausible future. Look at the spaghetti: no single path is "the forecast"; the *spread* is the message.
set.seed(2026)                                # same seed, so the paths repeat exactly
paths <- replicate(50, simulate(fit, nsim = 24, future = TRUE))   # 50 simulated futures, one per column
dim(paths)                                    # 24 months x 50 paths
viz_custom("ch10-paths", title = "50 futures the model thought possible in December 2019",
           subtitle = "Each grey line is one simulated path; gold is what actually happened",
           # history from 2017
           hist_date = ts_dates(window(train, start = 2017)), hist = as.numeric(window(train, start = 2017)),
           dates = ts_dates(fc_formula$mean), paths = t(paths),   # t() flips so each row is one path
           actual_date = ts_dates(actual), actual = as.numeric(actual), ylab = "$ millions", source = .course_src())

#| **From paths to an interval.** Simulate many more paths (2,000), then at each month take the 10th and 90th percentiles across paths. That *is* an 80% interval. A fan chart is just a summary of a cloud of possible futures.
many <- replicate(2000, simulate(fit, nsim = 24, future = TRUE))   # 24 x 2000 matrix of simulated futures
sim_lo <- apply(many, 1, quantile, probs = 0.10)   # apply over rows (months): 10th percentile across paths
sim_hi <- apply(many, 1, quantile, probs = 0.90)   # 90th percentile; together an 80% interval

#| **Compare the three methods.** They agree closely on width, because they share the same model. Then count how many of the 24 actual months fell inside each 80% interval. The method of computing the interval matters far less than the model's assumption that the future will be as calm as the past.
inside <- function(lo, hi) sum(actual >= lo & actual <= hi)   # helper: count months inside [lo, hi]
# one row per method; [1, 1] = month 1, first level (80%); [24, 1] = month 24, 80%
cmp <- data.frame(
  `Width Jan 2020` = c(fc_formula$upper[1, 1] - fc_formula$lower[1, 1], fc_boot$upper[1, 1] - fc_boot$lower[1, 1], sim_hi[1] - sim_lo[1]),
  `Width Dec 2021` = c(fc_formula$upper[24, 1] - fc_formula$lower[24, 1], fc_boot$upper[24, 1] - fc_boot$lower[24, 1], sim_hi[24] - sim_lo[24]),
  `Months inside (of 24)` = c(inside(fc_formula$lower[, 1], fc_formula$upper[, 1]), inside(fc_boot$lower[, 1], fc_boot$upper[, 1]), inside(sim_lo, sim_hi)),
  # check.names = FALSE keeps spaces
  row.names = c("Formula", "Bootstrap", "Simulated paths"), check.names = FALSE)
cmp                                           # widths in $ millions; an honest 80% interval holds about 19 of 24
viz_table(cmp, digits = 0, title = "Three ways to build an 80% interval, one shared blind spot")
