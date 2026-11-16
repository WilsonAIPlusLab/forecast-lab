#| **You are the analyst.** Your manager wants two weekly claims series turned into monthly numbers, to sit next to the monthly jobs report. **Initial claims** (`ICSA`) count *new* filings during each week: a **flow**. **Continuing claims** (`CCSA`) count the people *currently* on benefits: a **stock**. Pick the right monthly summary for each, fill the two blanks, and press **Run & check**.
ic <- read.csv("data/ICSA.csv")                         # weekly initial claims (SA), one row per week
cc <- read.csv("data/CCSA.csv")                         # weekly continuing claims (SA)
ic$month <- substr(ic$observation_date, 1, 7)           # "YYYY-MM" of the week-ending Saturday
cc$month <- substr(cc$observation_date, 1, 7)
last_value <- function(x) tail(x, 1)                    # end-of-period: the last week in each month

# 1. Flow -> a typical week in the month (what FRED reports). Blank: the summary function
ic_m <- aggregate(ICSA ~ month, data = ic, FUN = ______)
# 2. Stock -> the number on benefits at month end. Blank: the end-of-period helper defined above
cc_m <- aggregate(CCSA ~ month, data = cc, FUN = ______)

# For comparison: the sum of weekly initial claims (a monthly total)
ic_sum <- aggregate(ICSA ~ month, data = ic, FUN = sum)
both <- merge(ic_m, ic_sum, by = "month", suffixes = c("_avg", "_sum"))   # average and sum side by side
subset(both, month %in% c("2026-09", "2026-10"))        # %in% keeps rows whose month is in the list
tail(cc_m, 2)                                           # continuing claims at the end of each month
