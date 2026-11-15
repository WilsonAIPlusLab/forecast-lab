#| **Twenty indicators, one recipe.** With many series you never copy-paste code per series. You write one small function and apply it over a list. Levels such as jobs, output and sales become monthly growth rates (100 × change in log). Rates and spreads become monthly changes. Weekly and daily series are averaged to months first with `to = "month"`.
# series in levels (jobs, output, sales, claims): turn into monthly % growth rates
growth  <- c("PAYEMS", "IANA", "INDPRO", "HOUST", "PERMIT", "DSPIC96", "TOTALSA", "PCE", "RSFSXMV",
             "RSMVPD", "RSFHFS", "RSEAS", "RSDBS", "RSCCAS", "RSFSDP", "ICSA", "CCSA")
changes <- c("AWHMAN", "BAA10Y", "NFCI")               # hours, spreads, indexes: use plain monthly changes
weekly_or_daily <- c("ICSA", "CCSA", "BAA10Y", "NFCI") # these must be averaged to months first
# helper: download one series and make it stationary
transform1 <- function(id) {
  x <- fred(id, to = if (id %in% weekly_or_daily) "month" else NULL)   # %in% asks "is id in this list?"
  if (id %in% growth) 100 * diff(log(x)) else diff(x)  # % growth (100 x log change) or simple change
}
series <- lapply(c(growth, changes), transform1)       # lapply: run transform1 on each ID, get a list of 20

#| **Stack them into one panel**: rows are months, columns are series. `na.omit` keeps the months where all 20 exist (January 1993 to September 2026). This is the "wide" shape that principal components need.
panel <- do.call(cbind, series)                        # cbind all 20 list items side by side
colnames(panel) <- c(growth, changes)                  # name each column after its FRED ID
panel <- na.omit(window(panel, start = c(1993, 1), end = c(2026, 9)))   # drop months with any gap
dim(panel)                                             # months x series

#| **Standardize, then tame the outliers.** `scale()` gives every series mean 0 and standard deviation 1, so a series doesn't dominate just because its units are big. Then we clip values beyond ±4 standard deviations. Without this step, the single month of April 2020 hijacks the first component. Count the clipped cells: 68 of the 8,100, and 47 of them fall in 2020.
Z <- scale(as.data.frame(panel))                       # each column: subtract its mean, divide by its sd
clipped <- abs(Z) > 4                                  # TRUE where a value is beyond +/-4 sd
sum(clipped)                                           # how many cells will be clipped
table(floor(time(panel))[row(clipped)[clipped]])       # count of clipped cells by year
Z <- pmax(pmin(Z, 4), -4)                              # clip: cap at +4, floor at -4

#| **Principal components in one line.** `prcomp()` finds the weighted average of the 20 series that captures the most shared variation (component 1), then the next best one uncorrelated with it, and so on. The **scree plot** shows each component's share of total variance. One component stands far above the rest: a common "economic activity" factor.
pc <- prcomp(Z)                                        # principal component analysis (PCA)
share <- pc$sdev^2 / sum(pc$sdev^2)                    # share of total variance per component
round(share[1:5], 3)                                   # first five shares
viz_bars(round(100 * share[1:8], 1), labels = paste("PC", 1:8), sort = FALSE,   # scree plot, in %
         title = "One factor stands out: share of variance explained (%)", xlab = "% of total variance")

#| **What is the factor made of?** The **loadings** are the weights on each series. The sign of a principal component is arbitrary, so we flip it to make payrolls load positively. Then "up" means a stronger economy. Notice that claims and credit spreads load *negatively*: they rise when the economy weakens.
w <- pc$rotation[, 1]                                  # loadings (weights) of component 1, one per series
if (w["PAYEMS"] < 0) w <- -w                           # flip sign so payrolls load positively
viz_bars(round(w, 2), labels = names(w), title = "Almost every indicator loads on the factor, with the expected sign",
         xlab = "loading on component 1")

#| **The factor through time, with recessions shaded.** We plot its 3-month moving average, as the Chicago Fed does with its own 85-series index (CFNAI-MA3). It plunges in 2001, 2008–09 and 2020, and is near zero (average growth) today.
# factor = weighted sum of series (%*% = matrix product)
factor <- ts(Z %*% w, start = start(panel), frequency = 12)
ma3 <- stats::filter(factor, rep(1 / 3, 3), sides = 1)        # 3-month trailing average (this and 2 prior months)
viz_ts(`Activity factor (3-mo avg)` = ma3, recessions = TRUE, ylab = "standard units",
       title = "One line summarizes 20 indicators, and it falls in every recession")
round(window(ma3, start = c(2026, 7)), 2)              # latest readings; near 0 = average growth
