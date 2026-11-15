# CPI-U, all items, seasonally adjusted, index 1982-84 = 100 (monthly).
# Read the raw CSV, so the unpublished October 2025 stays NA (fred() would interpolate it).
raw <- read.csv("data/CPIAUCSL.csv")
cpi <- ts(raw$CPIAUCSL, start = c(1947, 1), frequency = ______)

# 1. Year-over-year inflation in percent: compare each month with the same month a year earlier
infl <- 100 * (cpi / stats::lag(cpi, ______) - 1)

# 2. Look at the last three months. Why is the final value NA?
tail(infl, 3)

# 3. The latest month for which inflation can be computed
latest <- infl[max(which(!is.na(infl)))]
latest
