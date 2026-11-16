retail <- fred("RSAFS", start = 2022)          # U.S. retail & food services sales, $ millions, seasonally adjusted
n <- length(retail)                            # number of months
lo <- hi <- actual <- numeric(24)              # empty slots for the last 24 months
for (i in 1:24) {                              # stand one month before each of the last 24 months
  t <- n - 24 + i                              # position of the target month
  past <- retail[1:(t - 1)]                    # only the data available a month earlier
  s <- sd(diff(past))                          # typical size of a month-to-month change
  lo[i] <- past[t - 1] - qnorm(0.9) * s        # naive forecast (last month) minus 1.28 typical changes
  hi[i] <- past[t - 1] + qnorm(0.9) * s        # ... plus 1.28 typical changes: an 80% band
  actual[i] <- retail[t]                       # what really happened
}

# 1. A hit: the actual value landed inside the band (TRUE/FALSE for each month)
inside <- actual >= lo & actual <= hi
# 2. Coverage: the share of hits, in percent (the mean of TRUE/FALSE is the share TRUE)
coverage <- 100 * mean(inside)
# 3. Which side did the misses fall on?
above <- sum(actual > hi)                      # sales came in higher than the band
below <- sum(actual < lo)                      # sales came in lower than the band

c(hits = sum(inside), coverage = round(coverage, 1), above = above, below = below)
