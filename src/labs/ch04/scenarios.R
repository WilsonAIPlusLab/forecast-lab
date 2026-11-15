#| **Same data and model as before**, but now fitted with `tslm()`, so that `forecast()` can produce dated forecasts with prediction intervals. We use all data through the latest month.
library(forecast)
veh <- fred("TOTALSA"); gas <- fred("GASREGW", to = "month"); mr <- fred("MORTGAGE30US", to = "month")
un  <- fred("UNRATE")
d <- window(ts.intersect(veh, gas, un, mr), start = c(1993, 1))
chip <- ts(as.numeric(floor(time(d)) %in% 2021:2022), start = start(d), frequency = 12)
d <- cbind(d, chip); colnames(d) <- c("veh", "gas", "un", "mr", "chip")
fit <- tslm(veh ~ gas + un + mr + chip, data = d)
tail(d, 1)

#| **Write each scenario as a table of future driver values**, one row per month for the next 12 months. The baseline holds every driver at today's value. "Gas hits $5" ramps gas up to $5.00 over three months and keeps it there. "Squeeze" adds a weaker job market and 8% mortgage rates on top.
h <- 12; now <- d[nrow(d), ]
ramp <- function(from, to) c(seq(from, to, length.out = 4)[-1], rep(to, h - 3))
base    <- data.frame(gas = rep(now["gas"], h), un = rep(now["un"], h), mr = rep(now["mr"], h), chip = 0)
gas5    <- transform(base, gas = ramp(now["gas"], 5))
squeeze <- transform(gas5, un = seq(now["un"], 5.5, length.out = h), mr = ramp(now["mr"], 8))
squeeze

#| **One forecast per scenario.** `forecast(fit, newdata = …)` plugs each driver path into the fitted equation and adds prediction intervals. This is **scenario forecasting**: you are not predicting gas prices, you are asking *what if*.
f_base    <- forecast(fit, newdata = base)
f_gas5    <- forecast(fit, newdata = gas5)
f_squeeze <- forecast(fit, newdata = squeeze)
viz_compare(history = window(d[, "veh"], start = 2022), Baseline = f_base,
            `Gas hits $5` = f_gas5, Squeeze = f_squeeze,
            title = "$5 gas alone trims sales; a weaker job market hurts far more")

#| **How much does each scenario move sales?** In a linear model the gap between two scenarios is just slope × change in the driver. Gas rising about 69 cents times the gas slope gives the gas gap; the squeeze adds the unemployment and mortgage-rate effects.
gap <- c(`Gas hits $5` = mean(f_gas5$mean - f_base$mean), Squeeze = mean(f_squeeze$mean - f_base$mean))
round(gap, 2)
round(coef(fit)["gas"] * (5 - now["gas"]), 2)

#| **Now look at the uncertainty.** The fan shows 80% and 95% prediction intervals for the gas scenario. They are wide: about ±2.6 million cars at 95%. And they are *too narrow*, for two reasons: they assume the driver path is known exactly, and they ignore the autocorrelated errors you found in the first lab.
viz_forecast(f_gas5, from = 2022, title = "Even if gas is exactly $5, the 95% band spans about 5 million cars",
             ylab = "millions of units, SAAR")
