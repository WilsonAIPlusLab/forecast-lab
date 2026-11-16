nsa <- fred("RSXFSN", start = 2015)            # raw retail sales excl. food services, $ millions, NSA
sa <- fred("RSAFS", start = 2015) - fred("RSFSDP", start = 2015)   # Census SA version of the same aggregate

# 1. Census's combined seasonal factor for every month: raw sales divided by adjusted sales
factor <- ______ / sa                          # blank: which series goes on top?

# 2. December 2025 in words: how far above a typical month, in percent?
f_dec <- window(factor, start = c(2025, 12), end = c(2025, 12))   # one number: the December 2025 factor
pct_above <- 100 * (______ - 1)                # blank: the factor you just picked out
round(pct_above, 1)

# 3. The same effect in dollars: how much of December's sales was "just December"? ($ billions)
round((window(nsa, start = c(2025, 12), end = c(2025, 12)) - window(sa, start = c(2025, 12), end = c(2025, 12))) / 1000, 1)
