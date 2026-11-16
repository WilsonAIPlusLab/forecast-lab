# Regular gasoline, $ per gallon (weekly, not seasonally adjusted), averaged to monthly
gas = fred("GASREGW", to="month")
cpi = fred("CPIAUCSL")                        # CPI-U, index 1982-84 = 100, SA (fred() fills Oct 2025)
cpi_now = cpi.loc["2026-10-01"]               # CPI in October 2026

# 1. Every month's price in October-2026 dollars: price x (CPI now / CPI then)
real_gas = (gas * ______ / cpi).dropna()      # blank: the price level you are converting INTO

# 2. The nominal record and the real record (.idxmax() = date label of the largest value)
nominal_peak = gas.idxmax()                   # month with the highest sticker price
real_peak = real_gas.______()                 # blank: the method that returns the date of the LARGEST value

# 3. Compare the two records with today's price
print(f"now ${gas['2026-10-01']:.2f}   nominal 2022 ${gas['2022-06-01']:.2f}   "   # f-string: :.2f = two decimals
      f"real 2022 ${real_gas['2022-06-01']:.2f}   real 2008 ${real_gas['2008-06-01']:.2f}")
print(nominal_peak.date(), real_peak.date())  # .date() drops the time part for printing
