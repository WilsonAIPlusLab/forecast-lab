veh <- fred("TOTALSA"); gas <- fred("GASREGW", to = "month"); mr <- fred("MORTGAGE30US", to = "month")
un  <- fred("UNRATE")
d <- window(ts.intersect(veh, gas, un, mr), start = c(1993, 1))
chip <- ts(as.numeric(floor(time(d)) %in% 2021:2022), start = start(d), frequency = 12)
d <- cbind(d, chip); colnames(d) <- c("veh", "gas", "un", "mr", "chip")
fit <- lm(veh ~ gas + un + mr + chip, data = d)
now <- tail(as.data.frame(d), 1)   # the latest month: October 2026

# 1. Two scenarios: everything at today's values, except the mortgage rate
today    <- data.frame(gas = now$gas, un = now$un, mr = now$mr, chip = 0)
low_rate <- data.frame(gas = now$gas, un = now$un, mr = ______, chip = 0)   # rates fall to 5%

# 2. Predicted sales with 95% prediction intervals
p_today <- predict(fit, newdata = today, interval = "prediction")
p_low   <- predict(fit, newdata = ______, interval = "prediction")
out <- rbind(p_today, p_low); rownames(out) <- c("today", "rates at 5%")
out

# 3. How many more cars (millions, SAAR) does the model expect at 5%?
gap <- p_low[, "fit"] - p_today[, "fit"]
gap
