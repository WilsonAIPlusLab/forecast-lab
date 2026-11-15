#| **Load the demand series and three drivers.** Light vehicle sales are seasonally adjusted, in millions of units at an annual rate (SAAR). Gas prices and mortgage rates are weekly, so `to = "month"` averages them to months. One quirk: the October 2025 unemployment rate was never published (the government shutdown stopped the survey). `fred()` fills that single month by linear interpolation between September and November and prints a note saying so.
veh <- fred("TOTALSA")                     # light vehicle sales, millions, SAAR
gas <- fred("GASREGW", to = "month")       # regular gasoline, $ per gallon
mr  <- fred("MORTGAGE30US", to = "month")  # 30-year mortgage rate, %
un  <- fred("UNRATE")                     # unemployment rate, %

#| **Line the series up month by month.** `ts.intersect()` keeps only the months where all four exist (gas prices start in 1990), and we start in 1993. The **chip** column is an *event dummy*: 1 during the 2021–2022 semiconductor shortage, when dealers had too few cars to sell, and 0 otherwise.
# ts.intersect(): join the four series, keeping only months they share; window(): keep Jan 1993 onward
d <- window(ts.intersect(veh, gas, un, mr), start = c(1993, 1))
# chip dummy: time(d) gives each month as a decimal year; floor() keeps the year; %in% tests membership
chip <- ts(as.numeric(floor(time(d)) %in% 2021:2022), start = start(d), frequency = 12)
d <- cbind(d, chip); colnames(d) <- c("veh", "gas", "un", "mr", "chip")   # add chip as a 5th column, give short names
# d[, "veh"] means "all rows, column veh"; facet = TRUE draws one panel per series
viz_ts(`Vehicle sales (mn, SAAR)` = d[, "veh"], `Gas ($/gal)` = d[, "gas"],
       `Unemployment (%)` = d[, "un"], `Mortgage rate (%)` = d[, "mr"], facet = TRUE,
       recessions = TRUE, title = "Car sales fall when unemployment jumps")   # shade U.S. recessions

#| **Ordinary least squares in one line.** `lm(y ~ x1 + x2 + x3)` finds the intercept and slopes that make the sum of squared residuals as small as possible. Read each slope as *the change in sales for a one-unit change in that driver, holding the other drivers constant*. `summary()` adds standard errors, t-statistics and R².
library(lmtest); library(sandwich)         # coeftest() and NeweyWest() for corrected standard errors
m0 <- lm(veh ~ gas + un + mr, data = d)    # OLS: sales explained by gas, unemployment, mortgage rate
summary(m0)                                # coefficients, standard errors, t-stats, R²

#| **Add the event dummy.** The dummy's coefficient is a level shift: how many million fewer cars per year were sold during the chip shortage than the drivers alone predict. Notice that R² jumps and the other slopes move, because the model no longer has to bend them to explain 2021–2022.
m1 <- lm(veh ~ gas + un + mr + chip, data = d)   # same model plus the chip-shortage dummy
summary(m1)

#| **Check the residuals before trusting the standard errors.** OLS standard errors assume each month's error is unrelated to the last. In time series that is rarely true: if the model under-predicts this month, it probably under-predicts next month too. The bars far above the dashed band show strong **autocorrelation**.
viz_acf(resid(m1), lag.max = 24, title = "The model's misses persist for months")   # autocorrelation of residuals, lags 1-24 months

#| **Newey–West standard errors** fix the inference (not the coefficients) for autocorrelation and changing variance. `coeftest()` from **lmtest** reprints the table with the corrected errors from **sandwich**. The estimates are identical; the standard errors are two to five times larger, so the t-statistics shrink. Look at **chip**: 24 back-to-back months are really one episode, not 24 independent pieces of evidence, and its p-value rises from essentially zero to about 0.08.
nw <- coeftest(m1, vcov. = NeweyWest(m1))  # same estimates, autocorrelation-robust standard errors
nw                                         # columns: estimate, s.e., t value, p-value

#| **One table for the report.** Put the usual and the Newey–West standard errors side by side. Gas, unemployment and the mortgage rate stay significant at the 1% level; the chip dummy does not survive at 5%. (The Python tab, with a fixed 12-month lag window, finds it significant: the dummy's evidence is fragile.) Honest standard errors change the story you can tell.
# OLS s.e. = square root of the diagonal of the coefficient covariance matrix; nw[, 2] = NW s.e., nw[, 3] = NW t
tab <- data.frame(Estimate = coef(m1), `OLS s.e.` = sqrt(diag(vcov(m1))),
                  `Newey-West s.e.` = nw[, 2], `NW t` = nw[, 3], check.names = FALSE)   # keep names with spaces
viz_table(tab, digits = 3, title = "Vehicle sales drivers, 1993 to 2026 (millions of units, SAAR)")

#| **Logs turn slopes into percentages.** With `log(veh)` on the left and `log(gas)` on the right, the gas coefficient is an **elasticity**: the % change in sales for a 1% change in gas prices. Unemployment and the mortgage rate stay in levels, so their coefficients are **semi-elasticities**: multiply by 100 for the approximate % change in sales per one-point rise.
m_log <- lm(log(veh) ~ log(gas) + un + mr + chip, data = d)   # log-log for gas, log-level for the rest
round(coef(m_log), 4)                      # coefficients rounded to 4 decimals
