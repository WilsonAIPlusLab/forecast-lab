#| **Annual job growth since 1960.** We average payrolls over each year and take the % change, which gives 60 annual growth rates. Annual data have little autocorrelation, which the F-tests below assume. The question: has the *typical* growth rate stayed the same, or did it shift?
library(strucchange)
jobs <- fred("PAYEMS")
annual <- aggregate(jobs, nfrequency = 1, FUN = mean)
g <- window(100 * diff(log(annual)), start = 1960, end = 2019)   # % growth, 1960-2019

#| **The Chow test at every candidate date.** `Fstats(g ~ 1)` asks, for each possible break year, "does a model with a different mean before and after fit significantly better than one mean for all years?" It skips the first and last 15% of the sample (`from = 0.15`), where too few years would sit on one side.
fs <- Fstats(g ~ 1, from = 0.15)
sctest(fs)          # sup-F (Andrews 1993): is the LARGEST F unusually large?

#| **Plot the F-statistic curve with its 5% critical value.** The critical value is not the usual F table: when you hunt for the best date you get many tries, so the bar must be higher. `boundary()` gives Andrews's critical value. Where the curve peaks above it is the estimated break.
crit <- boundary(fs, alpha = 0.05)
viz_ts(`Chow F-statistic` = fs$Fstats, `5% critical value (sup-F)` = crit,
       title = "The F-statistic peaks at 2000: job growth downshifted", ylab = "F-statistic")

#| **Date the break and measure it.** `breakpoints()` (Bai and Perron) searches for the best break dates and uses BIC to decide how many there are. Then we compare average growth in each regime.
bp <- breakpoints(g ~ 1, h = 0.15)
breakdates(bp)
regime <- breakfactor(bp, label = "regime")
round(tapply(as.numeric(g), regime, mean), 2)

#| **Searching has a price.** Suppose you had picked 2000 *before* looking at the data. The ordinary Chow test at that one date (`type = "Chow"`) gives the same F = 11.2 but a p-value about ten times smaller than the sup-F test's. The sup-F p-value is the honest one here, because we found 2000 by trying every year.
sctest(g ~ 1, type = "Chow", point = which(time(g) == 2000))$p.value

#| **Now COVID.** Run the same date search on the monthly link between claims growth and job gains, 2010 to 2024. The F-statistic explodes at one date and is ordinary on either side of it. Look at the numbers around 2020.
claims <- fred("ICSA", to = "month")
d <- window(ts.intersect(dj = diff(jobs), dcl = 100 * diff(log(claims))), start = c(2010, 1), end = c(2024, 12))
fs_m <- Fstats(dj ~ dcl, data = d, from = 0.15)
round(window(fs_m$Fstats, start = c(2019, 12), end = c(2020, 6)), 1)

#| **One month is not a regime.** The spike sits on March 2020 alone, when the monthly average of claims rose about elevenfold (a log change of 241, which is what `dcl` records) but the big job losses were still to come in April. That looks less like a permanent new relationship and more like a few **extreme outliers**. Compare four ways to handle them: ignore them, add **one** dummy for the whole pandemic period, give each pandemic month its own dummy (*pulse dummies*), or drop those months. A single dummy only shifts the average, so the outliers still drag the slope. Pulse dummies and dropping give identical slopes.
covid  <- time(d) > 2020.1 & time(d) < 2022               # March 2020 to December 2021
D      <- data.frame(dj = as.numeric(d[, "dj"]), dcl = as.numeric(d[, "dcl"]))
pulses <- sapply(which(covid), function(i) as.numeric(seq_len(nrow(D)) == i))   # one 0/1 column per pandemic month
round(c(ignore_covid  = coef(lm(dj ~ dcl, data = D))[["dcl"]],
        one_dummy     = coef(lm(D$dj ~ D$dcl + covid))[["D$dcl"]],
        pulse_dummies = coef(lm(D$dj ~ D$dcl + pulses))[["D$dcl"]],
        drop_covid    = coef(lm(dj ~ dcl, data = D[!covid, ]))[["dcl"]]), 2)
