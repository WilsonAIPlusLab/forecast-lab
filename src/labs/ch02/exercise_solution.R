retail <- fred("RSXFSN", start = 2005)          # U.S. retail sales excl. food services, $ millions, NSA
fit <- stl(log(retail), s.window = 13, robust = TRUE)   # STL decomposition of log sales; robust = resist outliers
seasonal <- fit$time.series[, "seasonal"]        # seasonal component, on the log scale

# 1. Seasonally adjust: remove the seasonal component on the log scale, then go back to dollars
sa <- exp(log(retail) - seasonal)                # subtract in logs, exp() back to $ millions

# 2. Month-over-month growth of the ADJUSTED series, November -> December 2025, in percent
last2 <- window(sa, start = c(2025, 11), end = c(2025, 12))   # Nov and Dec 2025
growth <- 100 * (last2[2] / last2[1] - 1)        # new / old - 1: December over November
growth

# 3. For comparison: the raw (NSA) jump that a headline might report
raw2 <- window(retail, start = c(2025, 11), end = c(2025, 12))   # unadjusted Nov and Dec 2025
100 * (raw2[2] / raw2[1] - 1)                    # raw % change, December over November
