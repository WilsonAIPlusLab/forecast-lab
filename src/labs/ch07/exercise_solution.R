library(dynlm)
claims <- fred("ICSA", to = "month"); jobs <- fred("PAYEMS")
dj  <- diff(jobs)                    # jobs added each month, thousands
dcl <- 100 * diff(log(claims))       # % change in claims

# An ADL(1, 1): jobs added depend on last month's jobs added,
# and on claims growth this month and last month
fit <- dynlm(dj ~ L(dj, 1) + L(dcl, 0:1), start = c(1990, 1), end = c(2019, 12))
b <- coef(fit)          # b[1] intercept, b[2] phi, b[3] beta0, b[4] beta1
round(b, 3)

# 1. Impact multiplier: the effect of claims growth on jobs added in the SAME month
impact <- b[3]

# 2. Long-run multiplier: (sum of the claims coefficients) / (1 - phi)
long_run <- (b[3] + b[4]) / (1 - b[2])

round(c(impact = unname(impact), long_run = unname(long_run)), 1)
