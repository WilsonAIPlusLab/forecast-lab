#| **One spurious regression.** Two **independent** random walks: each step adds a fresh, unrelated random shock. By construction *x* tells you nothing about *y*. Regress one on the other anyway and read the t-statistic and R². `set.seed()` makes the "random" numbers reproducible.
set.seed(1974)                         # fixed seed: same random numbers every run
n <- 100                               # observations per series
x <- cumsum(rnorm(n))                  # random walk: running total of normal shocks
y <- cumsum(rnorm(n))                  # a second, completely independent random walk
fit <- lm(y ~ x)                       # regress y on x anyway
# t-statistic on the slope and R-squared, pulled from the regression summary
round(c(slope_t = summary(fit)$coefficients["x", "t value"], r_squared = summary(fit)$r.squared), 2)

#| **A fast way to get the same t-statistic.** In a regression with one predictor, t = r·√((n − 2)/(1 − r²)), where r is the correlation. This one-liner gives exactly the `lm()` answer and is about 50 times faster, which matters when we repeat the experiment 2,000 times in your browser.
t_stat <- function(x, y) { r <- cor(x, y); r * sqrt((length(x) - 2) / (1 - r^2)) }   # slope t from the correlation
t_stat(x, y)                           # same value as lm() above

#| **Repeat it 1,000 times, in levels and in differences.** `replicate()` runs the experiment again and again. In the second version we regress the *changes* `diff(y)` on `diff(x)`, which are independent white noise: there, |t| > 2 should happen only about 5% of the time. We also recover each regression's R² from its t-statistic, R² = t²/(t² + n − 2), and compare the medians.
one_run <- function(n = 100) {         # one experiment: two new independent random walks
  x <- cumsum(rnorm(n)); y <- cumsum(rnorm(n))
  c(levels = t_stat(x, y), differences = t_stat(diff(x), diff(y)))   # t in levels and in first differences
}
sims <- t(replicate(1000, one_run()))  # 1,000 rows, columns "levels" and "differences"
share_significant <- colMeans(abs(sims) > 2)   # share of runs with |t| > 2 in each column
round(share_significant, 3)
r2 <- sims^2 / (sims^2 + 98)          # R-squared from t (n = 100)
round(apply(r2, 2, median), 3)        # median R-squared, levels vs differences

#| **The headline numbers.** A test that is supposed to be wrong 5% of the time is wrong most of the time in levels. Granger and Newbold (1974) found the same with 50 observations, and the problem gets *worse*, not better, with more data.
viz_kpi(`Levels: share with |t| > 2` = sprintf("%.0f%%", 100 * share_significant[["levels"]]),   # format as a whole %
        `Differences: share with |t| > 2` = sprintf("%.0f%%", 100 * share_significant[["differences"]]),
        `Should be` = "5%")

#| **Look at the whole distribution of t-statistics.** In differences the histogram hugs ±2 the way a textbook t-distribution should. In levels it is spread out to ±20 and beyond.
viz_custom("ch07-hist", levels = sims[, "levels"], differences = sims[, "differences"], cutoff = 2,   # [, "col"] = one column
           xlab = "t-statistic on the slope", title = "In levels, 'significant' is the rule, not the exception",
           source = "Simulation: 1,000 pairs of independent random walks, n = 100")

#| **More data makes it worse.** Rerun the experiment for several sample sizes. With white-noise data, more observations shrink false alarms toward 5%. With random walks the false-alarm rate climbs, because the t-statistic grows with √n even though there is no relationship.
sizes <- c(25, 50, 100, 200, 400)      # sample sizes to try
# for each size m: 300 runs, share of levels regressions with |t| > 2
rate <- sapply(sizes, function(m) mean(abs(replicate(300, one_run(m)["levels"])) > 2))
setNames(round(100 * rate), sizes)     # false-alarm rate in %, labelled by sample size
viz_lines(sizes, `Levels (random walks)` = 100 * rate, `Nominal 5% rate` = rep(5, length(sizes)),
          xlab = "sample size n", ylab = "% of regressions with |t| > 2", zero = TRUE,
          title = "With random walks, more data means more false discoveries")
