library(tseries)                                       # adf.test(), kpss.test()
y <- fred("GS10", start = 1990)                        # 10-year Treasury yield, % (monthly average)

# 1. Test the level. ADF null: unit root. KPSS null: stationary.
p_adf  <- suppressWarnings(adf.test(y)$p.value)        # small p = evidence of stationarity
# Blank: the test whose null hypothesis is "stationary"
p_kpss <- suppressWarnings(______(y)$p.value)          # small p = evidence of a unit root

# 2. Test the month-to-month change in the yield
# Blank: the function that takes first differences
dy <- ______(y)                                        # change in the yield, percentage points
p_adf_d  <- suppressWarnings(adf.test(dy)$p.value)
p_kpss_d <- suppressWarnings(kpss.test(dy)$p.value)
round(c(level_ADF = p_adf, level_KPSS = p_kpss, change_ADF = p_adf_d, change_KPSS = p_kpss_d), 3)

# 3. Your decision: how many differences should the model use, 0 or 1?
# Blank: a number, based on the four p-values above
d <- ______
