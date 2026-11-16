# Your manager: "Claims and payrolls have a correlation of -0.97 over 2010-2019, so claims
# explain almost everything about jobs." Check that claim the way an analyst would.
claims <- window(fred("ICSA", to = "month"), start = c(2010, 1), end = c(2019, 12))   # initial claims a week, monthly average, SA
jobs   <- window(fred("PAYEMS"),          start = c(2010, 1), end = c(2019, 12))   # payroll jobs, thousands, SA
cpi    <- window(fred("CPIAUCSL"),        start = c(2010, 1), end = c(2019, 12))   # consumer price index, SA

# 1. Correlations in LEVELS (done for you): claims vs jobs, and CPI vs jobs
r_levels <- c(claims = cor(claims, jobs), cpi = cor(cpi, jobs))
round(r_levels, 2)

# 2. A function that turns a monthly series into its % change from the previous month
# Blank: 100 times the first difference of the log of x
g <- function(x) ______

# 3. The same correlations, but between monthly growth rates
# Blank: the monthly growth rate of the consumer price index
r_growth <- c(claims = cor(g(claims), g(jobs)), cpi = cor(______, g(jobs)))
round(r_growth, 2)
