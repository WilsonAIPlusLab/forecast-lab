# Regular gasoline, $ per gallon (weekly, not seasonally adjusted), averaged to monthly
gas <- fred("GASREGW", to = "month")
cpi <- fred("CPIAUCSL")                       # CPI-U, index 1982-84 = 100, SA (fred() fills Oct 2025)
cpi_now <- as.numeric(window(cpi, start = c(2026, 10), end = c(2026, 10)))   # CPI in October 2026, as a plain number

# 1. Every month's price in October-2026 dollars: price x (CPI now / CPI then)
real_gas <- gas * ______ / cpi                # blank: the price level you are converting INTO

# 2. The nominal record and the real record (which.max = position of the largest value)
nominal_peak <- ts_dates(gas)[which.max(gas)]             # month with the highest sticker price
real_peak <- ts_dates(real_gas)[which.______(real_gas)]   # blank: position of the LARGEST value

# 3. Compare the two records with today's price
at <- function(x, y, m) as.numeric(window(x, start = c(y, m), end = c(y, m)))   # value in one month
round(c(now = at(gas, 2026, 10), nominal_2022 = at(gas, 2022, 6),
        real_2022 = at(real_gas, 2022, 6), real_2008 = at(real_gas, 2008, 6)), 2)
c(nominal_peak = nominal_peak, real_peak = real_peak)
