#| **Flows add up.** Retail sales are a *flow*: dollars spent **during** each month. A quarter's sales are the sum of its three months. `aggregate()` converts a monthly `ts` to a lower frequency: `nfrequency = 4` means quarterly, and `FUN` says how to combine the three months.
retail <- fred("RSXFSN", start = 2015)
retail_q <- aggregate(retail, nfrequency = 4, FUN = sum)
window(retail_q, start = c(2025, 1))

#| **Stocks do not add up.** Payroll employment is a *stock*: the number of people on payrolls **at a point in time** (the pay period that includes the 12th of the month). Adding three months of jobs would triple-count every worker. Use the quarter's average, or its last month (end of period).
jobs <- fred("PAYEMS", start = 2019)
jobs_avg <- aggregate(jobs, nfrequency = 4, FUN = mean)
jobs_end <- aggregate(jobs, nfrequency = 4, FUN = function(v) tail(v, 1))

#| **The choice matters most when things move fast.** In 2020 Q2 payrolls collapsed in April and recovered partly in May and June. The quarterly average and the end-of-quarter value differ by millions of jobs (the units are thousands). Note also that `aggregate()` drops a final quarter that is not yet complete.
round(window(cbind(average = jobs_avg, end_of_quarter = jobs_end, gap = jobs_end - jobs_avg),
             start = c(2020, 1), end = c(2020, 4)))

#| **Daily data: the yield-curve spread.** `T10Y3M` is the 10-year minus 3-month Treasury yield, in percentage points, every business day. It is a *rate*, neither stock nor flow, so summing is meaningless. We read the raw file, drop the holidays (blank values), and label every day with its month.
raw <- read.csv("data/T10Y3M.csv")
raw <- raw[!is.na(raw$T10Y3M), ]
month <- substr(raw$observation_date, 1, 7)

#| **Two monthly versions of one daily series.** `tapply()` applies a function to each month's group of days: `mean` for the monthly average (what `fred("T10Y3M", to = "month")` returns), and "last value" for the month-end reading that markets quote.
avg <- ts(tapply(raw$T10Y3M, month, mean), start = c(1982, 1), frequency = 12)
eom <- ts(tapply(raw$T10Y3M, month, function(v) tail(v, 1)), start = c(1982, 1), frequency = 12)
all.equal(as.numeric(avg), as.numeric(fred("T10Y3M", to = "month")))

#| **Count inverted months.** An *inverted* yield curve (spread below zero) has come before every U.S. recession since the 1950s, with a few false alarms, so analysts watch it closely (Chapter 8 builds a recession model on it). Depending on how you aggregate, you get a different count, and in some months the two rules disagree about whether the curve was inverted at all.
recent <- window(cbind(avg, eom), start = 2019)
c(days_inverted   = sum(raw$T10Y3M[raw$observation_date >= "2019-01-01"] < 0),
  months_avg_inv  = sum(recent[, "avg"] < 0),
  months_eom_inv  = sum(recent[, "eom"] < 0),
  months_disagree = sum((recent[, "avg"] < 0) != (recent[, "eom"] < 0)))

#| **Plot both.** The month-end line is jumpier because it is one day's reading; the average smooths the month's noise. Neither is wrong: pick the one that matches the question you are answering, and say which one you used.
viz_ts(`Monthly average` = recent[, "avg"], `Month-end` = recent[, "eom"], ylab = "percentage points",
       recessions = TRUE, title = "Same daily data, two monthly series: average vs. month-end spread")
