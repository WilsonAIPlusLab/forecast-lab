library(tseries)                                       # adf.test(), kpss.test()
y <- fred("GS10", start = 1990)                        # 10-year Treasury yield, % (monthly average)

# 1. Test the level. ADF null: unit root. KPSS null: stationary.
p_adf  <- suppressWarnings(adf.test(y)$p.value)        # 0.79: cannot reject a unit root
p_kpss <- suppressWarnings(kpss.test(y)$p.value)       # 0.01 (capped): rejects stationarity

# 2. Test the month-to-month change in the yield
dy <- diff(y)                                          # change in the yield, percentage points
p_adf_d  <- suppressWarnings(adf.test(dy)$p.value)     # 0.01 (capped): rejects a unit root
p_kpss_d <- suppressWarnings(kpss.test(dy)$p.value)    # 0.10 (capped): cannot reject stationarity
round(c(level_ADF = p_adf, level_KPSS = p_kpss, change_ADF = p_adf_d, change_KPSS = p_kpss_d), 3)

# 3. Your decision: both tests say "unit root" for the level and "stationary" for the change
d <- 1                                                 # one difference: model the monthly change
