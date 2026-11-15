# vehicle sales (mn, SAAR), gas ($/gal), 30-year mortgage rate (%); weekly series averaged to months
veh <- fred("TOTALSA"); gas <- fred("GASREGW", to = "month"); mr <- fred("MORTGAGE30US", to = "month")
un  <- fred("UNRATE")                      # unemployment rate, %
d <- window(ts.intersect(veh, gas, un, mr), start = c(1993, 1))   # months all four share, from Jan 1993
# chip dummy: 1 in 2021-2022 (chip shortage), 0 otherwise
chip <- ts(as.numeric(floor(time(d)) %in% 2021:2022), start = start(d), frequency = 12)
d <- cbind(d, chip); colnames(d) <- c("veh", "gas", "un", "mr", "chip")
fit <- lm(veh ~ gas + un + mr + chip, data = d)   # the regression from the first lab, on all data
now <- tail(as.data.frame(d), 1)   # the latest month: October 2026

# 1. Two scenarios: everything at today's values, except the mortgage rate
# each scenario is a one-row data frame of driver values; chip = 0 means no shortage
today    <- data.frame(gas = now$gas, un = now$un, mr = now$mr, chip = 0)
# same as today, but the mortgage rate set to 5 (percent)
low_rate <- data.frame(gas = now$gas, un = now$un, mr = 5, chip = 0)   # rates fall to 5%

# 2. Predicted sales with 95% prediction intervals
# interval = "prediction" adds a 95% prediction interval: columns fit, lwr, upr
p_today <- predict(fit, newdata = today, interval = "prediction")
# same prediction for the low-rate scenario
p_low   <- predict(fit, newdata = low_rate, interval = "prediction")
out <- rbind(p_today, p_low); rownames(out) <- c("today", "rates at 5%")   # stack both rows, label them
out                                # forecast and 95% interval for each scenario

# 3. How many more cars (millions, SAAR) does the model expect at 5%?
gap <- p_low[, "fit"] - p_today[, "fit"]   # low-rate forecast minus today's forecast
gap
