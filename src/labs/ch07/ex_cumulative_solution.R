# Your manager asks: "If weekly claims jump 10% this month and stay there, how many fewer
# jobs will we see over this month and the next two, in total?"
library(dynlm)                       # lets you write lags inside a formula with L()
claims <- fred("ICSA", to = "month"); jobs <- fred("PAYEMS")   # initial claims (monthly avg) and payrolls, SA
dj  <- diff(jobs)                    # jobs added each month, thousands
dcl <- 100 * diff(log(claims))       # % change in claims

# ADL(1, 1): jobs added depend on last month's jobs added and on claims growth now and last month
fit <- dynlm(dj ~ L(dj, 1) + L(dcl, 0:1), start = c(1990, 1), end = c(2019, 12))
b   <- coef(fit)                     # [[k]] below extracts the k-th coefficient as a plain number
phi <- b[[2]]; b0 <- b[[3]]; b1 <- b[[4]]   # persistence of job gains; claims effect now; claims effect a month later

# Dynamic multipliers for a 1% rise in claims that lasts (thousands of jobs added vs normal)
m0 <- b0                             # month 0: the impact multiplier
m1 <- b1 + phi * m0                  # month 1: lagged claims effect + echo of month 0
m2 <- phi * m1                       # month 2: only the echo of month 1 is left

# Cumulative effect of a 10% jump over months 0, 1 and 2 (thousands of jobs)
cum3 <- 10 * (m0 + m1 + m2)          # 10 = size of the jump, in %
round(c(m0 = m0, m1 = m1, m2 = m2, cum3 = cum3), 1)
