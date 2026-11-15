#| **Rebuild the 20-series panel** from the factor lab in compact form, stopping in December 2019. A pre-COVID sample gives a clean test, and every regression and every factor below uses only data up to its own forecast origin.
library(forecast)                                      # for dm.test() at the end
# series in levels: turn into monthly % growth rates
growth  <- c("PAYEMS", "IANA", "INDPRO", "HOUST", "PERMIT", "DSPIC96", "TOTALSA", "PCE", "RSFSXMV",
             "RSMVPD", "RSFHFS", "RSEAS", "RSDBS", "RSCCAS", "RSFSDP", "ICSA", "CCSA")
changes <- c("AWHMAN", "BAA10Y", "NFCI")               # hours, spreads, indexes: use plain monthly changes
# helper: download one series and make it stationary
transform1 <- function(id) {
  # weekly/daily -> monthly
  x <- fred(id, to = if (id %in% c("ICSA", "CCSA", "BAA10Y", "NFCI")) "month" else NULL)
  if (id %in% growth) 100 * diff(log(x)) else diff(x)  # % growth (100 x log change) or simple change
}
panel <- do.call(cbind, lapply(c(growth, changes), transform1))   # transform all 20, glue as columns
colnames(panel) <- c(growth, changes)                  # name each column after its FRED ID
panel <- na.omit(window(panel, start = c(1993, 1), end = c(2019, 12)))   # 1993-2019, months with all 20
X <- as.matrix(as.data.frame(panel)); dates <- ts_dates(panel)   # plain numeric matrix + month dates

#| **A function that estimates the factors in real time.** At origin `o` it standardizes with means and standard deviations from rows 1 to `o` only, clips at ±4, and runs `prcomp`. Re-estimating at every origin is what a forecaster in that month could actually have done. Using the full-sample factor would leak the future into the past.
factors_at <- function(o, k = 2) {
  Z <- scale(X[1:o, ])                                 # standardize using rows 1..o only (no future data)
  prcomp(pmax(pmin(Z, 4), -4))$x[, 1:k]                # clip at +/-4, PCA; keep first k factor series
}

#| **The diffusion-index forecast** (Stock & Watson, 2002). Target: next month's industrial production growth (`INDPRO`, % per month). The benchmark is an AR(2) regression on the last two months of IP growth. The challenger adds the first two factors. Both are re-fit at each of 179 monthly origins, January 2005 to November 2019, so the forecasts cover February 2005 to December 2019.
g <- X[, "INDPRO"]                                     # IP growth, % per month
origins <- which(dates >= "2005-01-01" & dates <= "2019-11-01")   # row numbers of the forecast origins
res <- t(sapply(origins, function(o) {                 # loop over origins; t() gives one row per origin
  F <- factors_at(o)                                   # factors estimated with data up to o
  i <- 3:(o - 1)                                     # rows with a known next-month outcome
  # training data: y = next month's growth; g0, g1 = this and last month's growth; F1, F2 = factors
  d <- data.frame(y = g[i + 1], g0 = g[i], g1 = g[i - 1], F1 = F[i, 1], F2 = F[i, 2])
  new <- data.frame(g0 = g[o], g1 = g[o - 1], F1 = F[o, 1], F2 = F[o, 2])   # predictors at the origin
  c(actual = g[o + 1], AR = unname(predict(lm(y ~ g0 + g1, d), new)),       # truth and AR(2) forecast
    Factor = unname(predict(lm(y ~ g0 + g1 + F1 + F2, d), new)))            # AR(2) + two factors
}))
nrow(res)                                              # number of origins (179)

#| **Score it.** RMSE in percentage points of monthly IP growth, over the whole period and in the 2008–09 recession. The ratio below 1 means the factor model wins, but look at the size of the win: about 5% lower RMSE overall and 15% lower in the recession. That is a typical, honest result for a diffusion index. The gain is real but modest, and largest when the economy turns.
# root mean squared error per model
rmse <- function(r) sqrt(colMeans((r[, "actual"] - r[, c("AR", "Factor")])^2))
when <- dates[origins + 1]                             # the month each forecast was for
gfc <- when >= "2008-01-01" & when <= "2009-06-01"     # TRUE for recession months
tab <- rbind(`2005-2019` = rmse(res), `2008-09 recession` = rmse(res[gfc, ]))   # one row per period
tab <- cbind(tab, `Factor / AR` = tab[, "Factor"] / tab[, "AR"])                # below 1 = factors win
round(tab, 3)
viz_table(tab, digits = 3, highlight = "Factor / AR",
          title = "Factors beat the AR benchmark, but only modestly")

#| **Is the difference more than luck?** The Diebold–Mariano test from Chapter 3 compares the two error series. Here p ≈ 0.18: over 179 months, a 5% gain is too small to rule out luck. Gains of this size are common for diffusion indexes, and often too small for a single sample to prove.
# Diebold-Mariano test on the two error series; h = 1 for one-step-ahead forecasts
dm.test(res[, "actual"] - res[, "AR"], res[, "actual"] - res[, "Factor"], h = 1)
