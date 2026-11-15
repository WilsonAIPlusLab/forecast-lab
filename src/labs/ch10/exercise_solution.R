library(forecast)
clothing <- fred("MRTSSM448USN", start = 2022)        # U.S. clothing stores, $ millions, NSA
h <- round((2026 + 11/12 - tsp(clothing)[2]) * 12)     # months ahead to December 2026
fit <- ets(clothing)
set.seed(1)
demand <- replicate(5000, simulate(fit, nsim = h, future = TRUE)[h])

# A discount chain: thin margins, heavy markdowns on leftovers
cu <- 0.30   # cost of each $1 of demand you cannot serve
co <- 0.45   # cost of each $1 of stock left over

# 1. The critical ratio (the service level the costs justify)
cr <- cu / (cu + co)

# 2. The optimal stock: the demand quantile at the critical ratio
stock <- unname(quantile(demand, cr))
c(critical_ratio = cr, stock = round(stock), median_demand = round(median(demand)))
