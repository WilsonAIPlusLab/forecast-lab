library(forecast)                                      # Arima(), forecast()
pce <- fred("PCEPILFE", start = c(2000, 1))            # core PCE price index (2017 = 100), through Sept 2026
g   <- 100 * diff(log(pce))                            # monthly inflation: log difference x 100, % per month

# A model of the log differences: ARMA(1,1) with a mean (inflation drifts back to its average)
fit <- Arima(g, order = c(1, 0, 1), include.mean = TRUE)
fc  <- forecast(fit, h = 12)$mean                      # 12 monthly log changes, % (Oct 2026 to Sept 2027)

# 1. Cumulative log change from Sept 2026 to each future month (divide by 100 to undo the x 100)
# Blank: the function that keeps a running total
cum <- ______(fc) / 100

# 2. Back to the index: undo the log
# Blank: the inverse of log()
level <- as.numeric(tail(pce, 1)) * ______(cum)        # forecast index level for each future month
level[12]                                              # September 2027

# 3. Implied 12-month inflation for September 2027, in %
# Blank: the latest observed index level (September 2026), as a plain number
infl_12 <- 100 * (level[12] / ______ - 1)
infl_12
