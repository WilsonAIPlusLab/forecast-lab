library(dynlm)                       # lets you write lags inside a formula with L()
claims <- fred("ICSA", to = "month"); jobs <- fred("PAYEMS")   # initial claims (monthly avg) and payrolls, SA
dj  <- diff(jobs)                    # jobs added each month, thousands
dcl <- 100 * diff(log(claims))       # % change in claims

# An ADL(1, 1): jobs added depend on last month's jobs added,
# and on claims growth this month and last month
fit <- dynlm(dj ~ L(dj, 1) + L(dcl, 0:1), start = c(1990, 1), end = c(2019, 12))   # estimated by OLS, 1990-2019
b <- coef(fit)          # b[1] intercept, b[2] phi, b[3] beta0, b[4] beta1
round(b, 3)             # print the four coefficients

# 1. Impact multiplier: the effect of claims growth on jobs added in the SAME month
# Blank: one element of b (which coefficient is on lag-0 claims growth?)
impact <- ______

# 2. Long-run multiplier: (sum of the claims coefficients) / (1 - phi)
# Blank: the numerator; wrap a sum in parentheses so it is divided as a whole
long_run <- ______ / (1 - b[2])

round(c(impact = unname(impact), long_run = unname(long_run)), 1)   # unname() drops the coefficient labels
