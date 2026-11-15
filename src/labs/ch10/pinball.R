#| **Setup.** Train on retail sales 2010–2017 (`RSXFSN`, $ millions, NSA) and score on 2018–2019, a calm 24-month test period. We will forecast *quantiles*, not just a single number.
library(forecast)
retail <- fred("RSXFSN", start = 2010)
train  <- window(retail, end = c(2017, 12))
test   <- window(retail, start = c(2018, 1), end = c(2019, 12))
taus   <- c(0.1, 0.25, 0.5, 0.75, 0.9)

#| **The pinball loss.** For a quantile forecast $q$ at level $\tau$: if the truth $y$ lands *above* $q$ you pay $\tau (y - q)$; if it lands *below* you pay $(1-\tau)(q - y)$. For $\tau = 0.9$, under-forecasting costs 9 times as much as over-forecasting, so the best answer sits high: the 90th percentile.
pinball <- function(y, q, tau) ifelse(y >= q, tau * (y - q), (1 - tau) * (q - y))
err <- seq(-10, 10, by = 0.5)              # truth minus forecast
viz_lines(err, `tau = 0.1` = pinball(err, 0, 0.1), `tau = 0.5` = pinball(err, 0, 0.5), `tau = 0.9` = pinball(err, 0, 0.9),
          xlab = "truth minus forecast", ylab = "loss", zero = TRUE,
          title = "Pinball loss is lopsided on purpose")

#| **Quantile forecasts from three methods.** ETS quantiles come from 2,000 simulated paths. Seasonal naive quantiles come from its normal-theory intervals: the $\tau$ quantile is the lower or upper end of the $|2\tau - 1|$ interval. The third "method" is the ETS point forecast copied into every quantile, which is what you get if you ignore uncertainty.
fit <- ets(train)
set.seed(2026)
paths <- replicate(2000, simulate(fit, nsim = 24, future = TRUE))
q_ets <- t(apply(paths, 1, quantile, probs = taus))
sn_q <- function(tau) { f <- snaive(train, h = 24, level = 100 * abs(2 * tau - 1))
  if (tau < 0.5) f$lower[, 1] else if (tau > 0.5) f$upper[, 1] else f$mean }
q_sn <- sapply(taus, sn_q)
q_pt <- matrix(as.numeric(forecast(fit, h = 24)$mean), 24, length(taus))

#| **Score them.** Average the pinball loss over the 24 test months for each $\tau$, then average across $\tau$ for one overall number (lower is better). The overall average approximates half the **CRPS**, the standard score for a whole forecast distribution.
score <- function(Q) sapply(seq_along(taus), function(j) mean(pinball(as.numeric(test), Q[, j], taus[j])))
tab <- rbind(`ETS quantiles` = score(q_ets), `Seasonal naive quantiles` = score(q_sn), `ETS point forecast only` = score(q_pt))
colnames(tab) <- paste0("tau=", taus)
tab <- cbind(tab, Average = rowMeans(tab))
round(tab)
viz_table(tab, digits = 0, highlight = c(colnames(tab)), title = "Pinball loss ($ millions): honest quantiles beat a point forecast")

#| **Does each quantile do its job?** A good $\tau$ quantile should have the truth *below* it about $\tau$ of the time. Here the truth ran above most quantiles: sales in 2018–2019 grew faster than the model expected, so the whole forecast distribution sat too low. That is also why the point forecast scored better at $\tau = 0.1$ and $0.25$. Pinball loss catches bias as well as bad spread.
hit <- colMeans(as.numeric(test) <= q_ets)
round(rbind(target = taus, ETS = hit), 2)
