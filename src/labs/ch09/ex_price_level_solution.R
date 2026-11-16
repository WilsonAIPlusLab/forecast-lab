library(vars)                                 # VAR estimation and impulse responses
q <- function(id) fred(id, to = "quarter")    # helper: FRED series as quarterly averages
# inflation (annualized %), unemployment (%), funds rate (%); keep quarters where all three exist
y <- na.omit(ts.intersect(400 * diff(log(q("CPIAUCSL"))), q("UNRATE"), q("FEDFUNDS")))
y <- window(y, start = c(1960, 1), end = c(2000, 4))   # 1960Q1 to 2000Q4
colnames(y) <- c("infl", "unemp", "ffr")      # baseline ordering: the Fed moves last
m <- VAR(y, p = 4, type = "const")            # VAR(4) with a constant

# responses to a one-s.d. funds-rate shock, rows h = 0..20, rescaled to a 1-pp surprise hike
r <- irf(m, impulse = "ffr", n.ahead = 20, ortho = TRUE, boot = FALSE)$irf$ffr
infl_1pp <- r[, "infl"] / r[1, "ffr"]         # pp of ANNUALIZED inflation, quarter by quarter

# 1. Add up the inflation responses: after h quarters, the price level has absorbed all of them
cum_infl <- cumsum(infl_1pp)                  # running total of the inflation responses

# 2. Each quarter's inflation is at an annual rate (x 4), so one quarter adds only a quarter of it
price_1pp <- cum_infl / 4                     # % difference in the CPI level versus no hike

# 3. The CPI level 12 quarters (three years) after the hike, in % versus no hike
price12 <- price_1pp[13]                      # row 13 = h = 12 (row 1 is the shock quarter)
round(c(after_2q = price_1pp[3], after_12q = price12), 3)   # % difference in the CPI level
