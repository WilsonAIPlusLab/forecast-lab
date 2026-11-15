library(forecast)                                     # ets() and simulate()
clothing <- fred("MRTSSM448USN", start = 2022)        # U.S. clothing stores, $ millions, NSA
h <- round((2026 + 11/12 - tsp(clothing)[2]) * 12)     # months ahead to December 2026
fit <- ets(clothing)                                  # let ets() pick the model
set.seed(1)                                           # fix the random draws so results repeat exactly
demand <- replicate(5000, simulate(fit, nsim = h, future = TRUE)[h])   # 5,000 simulated December 2026 sales values

# A discount chain: thin margins, heavy markdowns on leftovers
cu <- 0.30   # cost of each $1 of demand you cannot serve
co <- 0.45   # cost of each $1 of stock left over

# 1. The critical ratio (the service level the costs justify)
cr <- cu / (cu + co)                                  # shortage cost / total of both costs = 0.40

# 2. The optimal stock: the demand quantile at the critical ratio
# 40th percentile of simulated demand; unname drops the "40%" label
stock <- unname(quantile(demand, cr))
# stock falls below median demand
c(critical_ratio = cr, stock = round(stock), median_demand = round(median(demand)))
