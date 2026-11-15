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
# blank: a formula using cu and co, giving a number between 0 and 1
cr <- ______

# 2. The optimal stock: the demand quantile at the critical ratio
# blank: the probability level for quantile(), an object you created in step 1
stock <- unname(quantile(demand, ______))
# compare stock with median demand
c(critical_ratio = cr, stock = round(stock), median_demand = round(median(demand)))
