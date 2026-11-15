# CPI-U, all items, seasonally adjusted, index 1982-84 = 100 (monthly).
# Read the raw CSV, so the unpublished October 2025 stays NA (fred() would interpolate it).
raw <- read.csv("data/CPIAUCSL.csv")          # data frame: observation_date and CPIAUCSL columns
cpi <- ts(raw$CPIAUCSL, start = c(1947, 1), frequency = ______)   # blank: observations per year for this series

# 1. Year-over-year inflation in percent: compare each month with the same month a year earlier
# stats::lag(x, k) shifts a ts in time; blank: how many months, and the sign decides past or future
infl <- 100 * (cpi / stats::lag(cpi, ______) - 1)

# 2. Look at the last three months. Why is the final value NA?
tail(infl, 3)                                 # last 3 values

# 3. The latest month for which inflation can be computed
latest <- infl[max(which(!is.na(infl)))]      # which() gives positions of non-missing values; max() = the last one
latest                                        # print it
