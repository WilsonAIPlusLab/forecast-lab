#| **Solution.** A flow becomes a weekly *average*: a rate that does not depend on how many weeks the month has. A stock becomes its *end-of-month* value (its monthly average would also be defensible). Never sum a stock: the same people would be counted four or five times.
ic <- read.csv("data/ICSA.csv")                         # weekly initial claims (SA), one row per week
cc <- read.csv("data/CCSA.csv")                         # weekly continuing claims (SA)
ic$month <- substr(ic$observation_date, 1, 7)           # "YYYY-MM" of the week-ending Saturday
cc$month <- substr(cc$observation_date, 1, 7)
last_value <- function(x) tail(x, 1)                    # end-of-period: the last week in each month

# 1. Flow -> average weekly claims in each month (FRED's default)
ic_m <- aggregate(ICSA ~ month, data = ic, FUN = mean)
# 2. Stock -> continuing claims in the last week of each month
cc_m <- aggregate(CCSA ~ month, data = cc, FUN = last_value)

# For comparison: the sum of weekly initial claims (a monthly total)
ic_sum <- aggregate(ICSA ~ month, data = ic, FUN = sum)
both <- merge(ic_m, ic_sum, by = "month", suffixes = c("_avg", "_sum"))   # average and sum side by side
subset(both, month %in% c("2026-09", "2026-10"))        # %in% keeps rows whose month is in the list
tail(cc_m, 2)                                           # continuing claims at the end of each month
