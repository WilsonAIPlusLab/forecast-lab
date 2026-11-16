# Your manager asks: "How much bigger is December than January, in percent?
# And how much bigger than November?" Read the seasonal dummies of a log model.
library(forecast)                          # for tslm()
retail <- window(fred("RSXFSN"), start = c(2012, 1))   # retail sales, $ millions, NSA
train  <- window(retail, end = c(2023, 12))   # fit on 2012 to 2023
covid  <- train * 0                        # all zeros, same dates as train
window(covid, start = c(2020, 4), end = c(2020, 4)) <- 1   # pulse dummy: April 2020 only
fit <- tslm(train ~ trend + season + covid, lambda = 0)   # log sales; January is the base month
b <- coef(fit)
round(b, 4)                                # season2 = February, ..., season12 = December

# 1. December vs January (the base month): exact % gap = 100 * (exp(b) - 1)
dec_vs_jan <- 100 * (exp(b["season12"]) - 1)   # December's coefficient is season12

# 2. December vs November: both are measured from January, so take the difference first
dec_vs_nov <- 100 * (exp(b["season12"] - b["season11"]) - 1)   # Dec minus Nov, both vs January
round(c(dec_vs_jan = unname(dec_vs_jan), dec_vs_nov = unname(dec_vs_nov)), 1)
