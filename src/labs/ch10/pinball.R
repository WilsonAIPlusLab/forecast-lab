#| **Setup.** Train on retail sales 2010–2017 (`RSXFSN`, $ millions, NSA) and score on 2018–2019, a calm 24-month test period. We will forecast *quantiles*, not just a single number.
library(forecast)                             # ets(), simulate(), snaive()
retail <- fred("RSXFSN", start = 2010)        # monthly U.S. retail sales, $ millions, not seasonally adjusted
train  <- window(retail, end = c(2017, 12))   # training set: 2010-2017
test   <- window(retail, start = c(2018, 1), end = c(2019, 12))   # test set: 2018-2019 (24 months)
taus   <- c(0.1, 0.25, 0.5, 0.75, 0.9)        # quantile levels (tau) to forecast

#| **The pinball loss.** For a quantile forecast $q$ at level $\tau$: if the truth $y$ lands *above* $q$ you pay $\tau (y - q)$; if it lands *below* you pay $(1-\tau)(q - y)$. For $\tau = 0.9$, under-forecasting costs 9 times as much as over-forecasting, so the best answer sits high: the 90th percentile.
# ifelse(test, if TRUE, if FALSE), element by element
pinball <- function(y, q, tau) ifelse(y >= q, tau * (y - q), (1 - tau) * (q - y))
err <- seq(-10, 10, by = 0.5)              # truth minus forecast
viz_lines(err, `tau = 0.1` = pinball(err, 0, 0.1), `tau = 0.5` = pinball(err, 0, 0.5), `tau = 0.9` = pinball(err, 0, 0.9),
          # loss for a forecast of 0 at three tau levels
          xlab = "truth minus forecast", ylab = "loss", zero = TRUE,
          title = "Pinball loss is lopsided on purpose")

#| **Quantile forecasts from three methods.** ETS quantiles come from 2,000 simulated paths. Seasonal naive quantiles come from its normal-theory intervals: the $\tau$ quantile is the lower or upper end of the $|2\tau - 1|$ interval. The third "method" is the ETS point forecast copied into every quantile, which is what you get if you ignore uncertainty.
fit <- ets(train)                             # let ets() pick the model
set.seed(2026)                                # fix the random draws so results repeat exactly
paths <- replicate(2000, simulate(fit, nsim = 24, future = TRUE))   # 24 months x 2,000 simulated futures
q_ets <- t(apply(paths, 1, quantile, probs = taus))   # per month, the tau quantiles across paths (24 x 5)
# seasonal naive tau quantile: lower end (tau < 0.5) or upper end (tau > 0.5) of the matching interval
sn_q <- function(tau) { f <- snaive(train, h = 24, level = 100 * abs(2 * tau - 1))
  if (tau < 0.5) f$lower[, 1] else if (tau > 0.5) f$upper[, 1] else f$mean }   # tau = 0.5 is the point forecast
q_sn <- sapply(taus, sn_q)                    # 24 x 5 matrix, one column per tau
# point forecast repeated in all 5 columns
q_pt <- matrix(as.numeric(forecast(fit, h = 24)$mean), 24, length(taus))

#| **Score them.** Average the pinball loss over the 24 test months for each $\tau$, then average across $\tau$ for one overall number (lower is better). The overall average approximates half the **CRPS**, the standard score for a whole forecast distribution.
# mean loss per tau
score <- function(Q) sapply(seq_along(taus), function(j) mean(pinball(as.numeric(test), Q[, j], taus[j])))
tab <- rbind(`ETS quantiles` = score(q_ets), `Seasonal naive quantiles` = score(q_sn), `ETS point forecast only` = score(q_pt))
colnames(tab) <- paste0("tau=", taus)         # column labels like "tau=0.1"
tab <- cbind(tab, Average = rowMeans(tab))    # average across tau, about half the CRPS
round(tab)                                    # $ millions; lower is better
viz_table(tab, digits = 0, highlight = c(colnames(tab)), title = "Pinball loss ($ millions): honest quantiles beat a point forecast")

#| **Does each quantile do its job?** A good $\tau$ quantile should have the truth *below* it about $\tau$ of the time. Here the truth ran above most quantiles: sales in 2018–2019 grew faster than the model expected, so the whole forecast distribution sat too low. That is also why the point forecast scored better at $\tau = 0.1$ and $0.25$. Pinball loss catches bias as well as bad spread.
hit <- colMeans(as.numeric(test) <= q_ets)    # per tau: share of months with the truth at or below the quantile
round(rbind(target = taus, ETS = hit), 2)     # compare each share with its target tau
