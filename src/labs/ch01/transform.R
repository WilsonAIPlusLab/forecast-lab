#| **One series, many views.** `RSXFSN` is U.S. retail sales excluding food services, in millions of dollars, **not seasonally adjusted** (NSA). Every December spikes because of holiday shopping. Keep that in mind: it decides which transformations make sense.
retail <- fred("RSXFSN", start = 2015)

#| **Differences: change in the data's own units.** `diff(x)` is $x_t - x_{t-1}$, here the change in dollars (millions) from the previous month. Notice the series loses one observation at the start: there is no "previous month" for the first month.
d1 <- diff(retail)
window(d1, start = c(2026, 1))

#| **Percent changes.** Month-over-month (MoM) compares with the previous month; year-over-year (YoY) compares with the **same month a year earlier**. `stats::lag(x, -k)` shifts the series *k* periods back in time, and R matches the two series by date before dividing.
mom <- 100 * (retail / stats::lag(retail, -1) - 1)
yoy <- 100 * (retail / stats::lag(retail, -12) - 1)

#| **Logs turn growth into differences.** $100 \times \Delta \log x_t$ is almost exactly the percent change when changes are small (compare the small months below), and drifts away for big ones such as December's holiday jump and January's post-holiday drop. Economists love logs because a constant growth rate becomes a straight line, and log changes add up across months.
dlog <- 100 * diff(log(retail))
round(window(cbind(mom, dlog), start = c(2025, 11), end = c(2026, 4)), 2)

#| **Annualized rates: "if this month's pace lasted a year."** Compound the monthly growth factor 12 times: $100\,[(x_t/x_{t-1})^{12} - 1]$. Only do this with **seasonally adjusted** data. Annualizing a seasonal swing (December +12%) would claim sales are on track to triple. So we switch to the SA version, `RSAFS` (retail *and food services*, so the dollar level is a little higher).
sa  <- fred("RSAFS", start = 2015)
ann <- 100 * ((sa / stats::lag(sa, -1))^12 - 1)

#| **Index to 100.** Divide by the 2019 average and multiply by 100. The units disappear and every number reads as "percent of the 2019 level", so series in dollars, tons or people can share one axis.
idx <- 100 * retail / mean(window(retail, start = c(2019, 1), end = c(2019, 12)))

#| **Compare them side by side** for the last six months. Read across one row: the same month of data tells completely different stories depending on the view. The MoM column zigzags with the calendar; YoY is steadier, because comparing a month with the same month a year earlier cancels the seasonal pattern.
both <- tail(cbind(retail, mom, yoy, dlog, ann, idx), 6)
tab <- data.frame(Month = format(as.Date(tail(ts_dates(retail), 6)), "%b %Y"),
                  `Level ($M)` = both[, "retail"], `MoM %` = both[, "mom"], `YoY %` = both[, "yoy"],
                  `100 x dlog` = both[, "dlog"], `Annualized % (SA)` = both[, "ann"],
                  `Index 2019=100` = both[, "idx"], check.names = FALSE)
tab
viz_table(tab, digits = 1, title = "Six months of retail sales, six ways to read them")

#| **See the difference.** Month-over-month growth of NSA data is dominated by the calendar: up every November and December, down every January. Year-over-year growth removes that pattern and shows the underlying trend, including the 2021 rebound and the 2022 inflation surge.
viz_ts(`Month over month` = window(mom, start = 2019), `Year over year` = window(yoy, start = 2019),
       ylab = "% change", title = "For seasonal data, MoM shows the calendar; YoY shows the trend")
