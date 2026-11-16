nsa = fred("RSXFSN", start=2015)               # raw retail sales excl. food services, $ millions, NSA
sa = fred("RSAFS", start=2015) - fred("RSFSDP", start=2015)   # Census SA version of the same aggregate

# 1. Census's combined seasonal factor for every month: raw sales divided by adjusted sales
factor = nsa / sa                              # factor > 1: month above typical; < 1: below

# 2. December 2025 in words: how far above a typical month, in percent?
f_dec = factor["2025-12-01"]                   # one number: the December 2025 factor
pct_above = 100 * (f_dec - 1)                  # factor 1.121 -> 12.1% above a typical month
print(round(pct_above, 1))

# 3. The same effect in dollars: how much of December's sales was "just December"? ($ billions)
print(round((nsa["2025-12-01"] - sa["2025-12-01"]) / 1000, 1))
