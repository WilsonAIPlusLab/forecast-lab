#| **Work on the log scale.** Retail's seasonal swings grow as sales grow: December adds a roughly constant *percentage*, not a constant number of dollars. Taking `log()` turns those percentage effects into constant additive ones, which is what `stl()` assumes. We start in 2005 so the 2008 crisis and COVID are both in the sample.
retail <- fred("RSXFSN", start = 2005)
y <- log(retail)

#| **Fit STL.** Two settings matter:
#| - `s.window = 13`: how many *years* each month's seasonal effect is smoothed over. Small = the seasonal pattern can change quickly; `"periodic"` = identical every year.
#| - `robust = TRUE`: down-weights outliers such as the COVID lockdown of spring 2020, so they land in the remainder instead of bending the trend and the seasonal pattern.
#|
#| The trend window `t.window` is left at its default, which R computes from the period and `s.window`.
fit <- stl(y, s.window = 13, robust = TRUE)
viz_decomp(fit, title = "STL on log retail sales: COVID lands in the remainder")

#| **Which months did the robust fit down-weight?** `fit$weights` is 1 for an ordinary month and near 0 for a month treated as an outlier. Expect the 2008–09 crisis and the spring of 2020.
ts_dates(retail)[fit$weights < 0.3]

#| **Seasonal factors.** Because we worked in logs, `exp(seasonal)` is a multiplicative factor. A December factor of 1.12 means "a typical December is 12% above the underlying level".
factors <- exp(fit$time.series[, "seasonal"])
round(window(factors, start = c(2025, 1), end = c(2025, 12)), 3)

#| **Seasonally adjust: remove only the seasonal part.** On the log scale, subtract the seasonal component, then `exp()` back to dollars. That is the same as dividing the raw data by the seasonal factor.
sa <- exp(y - fit$time.series[, "seasonal"])

#| **Compare with the official numbers.** The Census Bureau publishes seasonally adjusted retail sales made with X-13ARIMA-SEATS. FRED has no SA series for exactly our aggregate, but total retail & food services (`RSAFS`) minus food services & drinking places (`RSFSDP`) is the same aggregate, adjusted.
official <- fred("RSAFS", start = 2005) - fred("RSFSDP", start = 2005)
viz_ts(`Raw (NSA)` = window(retail, start = 2021), `Our STL adjustment` = window(sa, start = 2021),
       `Census SA (X-13)` = window(official, start = 2021), ylab = "$ millions",
       title = "Our homemade adjustment tracks the official one closely",
       subtitle = "U.S. retail sales excl. food services, $ millions per month")

#| **How close is close?** The mean absolute gap between our adjusted series and Census's, in percent. Under 1% means a 20-line R script got very near a statistical agency's production system. The gaps that remain come from calendar effects (trading days, holidays) that STL ignores and Census models explicitly.
round(100 * mean(abs(sa / official - 1)), 2)
