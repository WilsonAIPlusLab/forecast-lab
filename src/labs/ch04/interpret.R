#| **Same data as the drivers lab.** Monthly U.S. light vehicle sales (millions of units, seasonally adjusted annual rate), the gas price (\$ per gallon), the unemployment rate (%) and the 30-year mortgage rate (%), January 1993 to October 2026, plus the 2021–2022 chip-shortage dummy.
library(lmtest); library(sandwich)         # coeftest(), coefci() and NeweyWest()
veh <- fred("TOTALSA")                     # light vehicle sales, millions, SAAR
gas <- fred("GASREGW", to = "month")       # regular gasoline, $ per gallon (weekly averaged to months)
mr  <- fred("MORTGAGE30US", to = "month")  # 30-year mortgage rate, %
un  <- fred("UNRATE")                      # unemployment rate, %
d <- window(ts.intersect(veh, gas, un, mr), start = c(1993, 1))   # months all four share, from Jan 1993
chip <- ts(as.numeric(floor(time(d)) %in% 2021:2022), start = start(d), frequency = 12)   # 1 in 2021-22
d <- cbind(d, chip); colnames(d) <- c("veh", "gas", "un", "mr", "chip")
d <- as.data.frame(d)                      # a plain data frame is easier to rescale below

#| **One question, four functional forms.** Fit the same model four ways: sales in levels or logs, gas in levels or logs. Each gives a gas coefficient with a *different meaning* (units, percent, or elasticity). To compare them fairly, translate every one into the same business answer: *how many cars a year do we lose if gas goes from \$4 to \$5?* We use today's sales of 16.0 million to turn percentages into cars. Notice the split: the two forms with gas in dollars say about −0.48 million; the two with log(gas) say about −0.23. Logging gas assumes a dollar matters less when gas is already expensive (\$4 to \$5 is +25%, while \$2 to \$3 is +50%). Functional form is an assumption, so report the range.
m_ll  <- lm(veh ~ gas + un + mr + chip, data = d)             # level-level
m_lgl <- lm(log(veh) ~ gas + un + mr + chip, data = d)        # log-level
m_llg <- lm(veh ~ log(gas) + un + mr + chip, data = d)        # level-log
m_lgg <- lm(log(veh) ~ log(gas) + un + mr + chip, data = d)   # log-log
s_now <- tail(d$veh, 1)                    # latest sales, millions (October 2026)
b <- c(coef(m_ll)["gas"], coef(m_lgl)["gas"], coef(m_llg)["log(gas)"], coef(m_lgg)["log(gas)"])
# effect of $4 -> $5 in millions of cars, using each form's own rule
effect <- c(b[1] * 1,                      # level-level: b units per $1
            s_now * (exp(b[2] * 1) - 1),   # log-level: exact % change exp(b) - 1, times sales
            b[3] * log(5 / 4),             # level-log: b times the change in log gas
            s_now * ((5 / 4)^b[4] - 1))    # log-log: exact % change (5/4)^b - 1, times sales
tab <- data.frame(Form = c("level-level", "log-level", "level-log", "log-log"),
                  `Gas coefficient` = round(b, 4),
                  `Read it as` = c("mn cars per $1", "x100 = % per $1", "/100 = mn cars per 1%", "% per 1% (elasticity)"),
                  `$4 to $5, mn cars` = round(effect, 2), check.names = FALSE)   # keep names with spaces
tab                                        # also print it to the console
viz_table(tab, title = "Four forms, four meanings, one comparable answer")

#| **Exact versus approximate percent.** In a log model, `100 * b` is only an approximation of the percent effect. The exact effect is `100 * (exp(b) - 1)`. For small *b* they agree. For the chip dummy in the log-level model, *b* is about −0.16, and the two readings differ by more than a percentage point. Use the exact one whenever |*b*| is above about 0.10.
b_chip <- coef(m_lgl)["chip"]              # log-level chip-shortage coefficient
round(c(approx_pct = 100 * unname(b_chip), exact_pct = 100 * (exp(unname(b_chip)) - 1)), 1)   # both, in %

#| **Rescaling units changes the coefficient, never the story.** Measure sales in *thousands* of cars and gas in *cents* per gallon. The gas coefficient becomes −0.48 × 1,000 / 100 = −4.8 thousand cars per cent. Its standard error is rescaled by the same factor, so the **t-statistic, the p-value and R² do not change at all**.
d$veh_th  <- d$veh * 1000                  # sales in thousands of cars
d$gas_cts <- d$gas * 100                   # gas in cents per gallon
m_units <- lm(veh_th ~ gas_cts + un + mr + chip, data = d)
# [ "gas", ] picks the gas row; columns: estimate, s.e., t value, p-value
rbind(`millions, $`      = coef(summary(m_ll))["gas", ],
      `thousands, cents` = coef(summary(m_units))["gas_cts", ])

#| **"Holding the other drivers fixed" is not a figure of speech.** On its own, the mortgage rate has a tiny *positive* slope: months with high rates were not months with low sales. Add unemployment and the slope turns negative. Why? Mortgage rates were high in the 1990s, when jobs were plentiful, and low after 2008, when unemployment was high. Without unemployment in the model, the mortgage rate soaks up part of the job market's effect. Each new driver changes what "holding fixed" means.
slope_mr <- function(f) unname(coef(lm(f, data = d))["mr"])   # fit a model, return its mortgage-rate slope
round(c(alone        = slope_mr(veh ~ mr),
        `+ un`       = slope_mr(veh ~ mr + un),
        `+ un + gas` = slope_mr(veh ~ mr + un + gas),
        `+ chip too` = slope_mr(veh ~ mr + un + gas + chip)), 3)   # the last is the drivers-lab model
round(cor(d[, c("mr", "un", "gas")]), 2)   # how the drivers move together

#| **A confidence interval, read in words.** `coefci()` gives a 95% interval for each coefficient; with `vcov. = NeweyWest(...)` it uses the honest, autocorrelation-robust standard errors. Read the gas row as: *each extra dollar a gallon goes with between about 160,000 and 810,000 fewer cars a year, holding jobs and rates fixed.* The range is wide; that width is part of the answer.
ci <- coefci(m_ll, vcov. = NeweyWest(m_ll))   # 95% intervals with Newey-West standard errors
round(cbind(Estimate = coef(m_ll), ci), 3)
