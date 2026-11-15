#| **The decision.** You plan December merchandise for U.S. clothing stores (`MRTSSM448USN`, monthly sales in $ millions, NSA). Stock is valued at retail prices, so "stock" and "demand" are in the same $ millions. We fit on data since January 2022, after the pandemic swings, and target December 2026.
library(forecast)
clothing <- fred("MRTSSM448USN", start = 2022)
h <- round((2026 + 11/12 - tsp(clothing)[2]) * 12)   # months from the last observation to Dec 2026
fit <- ets(clothing)
c(model = fit$method, months_ahead = h)

#| **A demand distribution, not a number.** Simulate 5,000 possible futures and keep each one's December value. The spread of `demand` is our uncertainty about December sales.
set.seed(2026)
demand <- replicate(5000, simulate(fit, nsim = h, future = TRUE)[h])
point  <- forecast(fit, h = h)$mean[h]
round(c(point_forecast = point, quantile(demand, c(0.05, 0.5, 0.95))))

#| **Costs of being wrong.** Every $1 of demand you cannot serve loses $0.60 (forgone margin), so $c_u = 0.60$. Every $1 of stock left over costs $0.25 in markdowns and holding, so $c_o = 0.25$. These are assumptions for the example; plug in your own.
cu <- 0.60
co <- 0.25

#| **The newsvendor rule.** Stock the quantile of demand at the **critical ratio** $c_u/(c_u + c_o)$. Here that is about 0.71: you should be out of stock in only 29% of Decembers, because running out costs more than leftovers do. The critical ratio is the **service level** this cost structure justifies.
critical_ratio <- cu / (cu + co)
stock <- unname(quantile(demand, critical_ratio))
round(c(critical_ratio = critical_ratio, stock = stock, safety_stock = stock - point), 3)
viz_custom("ch10-hist", values = demand, bins = 40, xlab = "December 2026 sales ($ millions)",
           markers = list(list(x = point, label = "Point forecast"), list(x = stock, label = "Optimal stock")),
           title = "Stock above the point forecast because running out costs more", source = .course_src())

#| **Check it by brute force.** Compute the expected cost of every stock level from 38,000 to 43,000 using the simulated demands. The minimum lands at the critical-ratio quantile, as the theory promises.
grid <- seq(38000, 43000, by = 50)
exp_cost <- sapply(grid, function(Q) mean(cu * pmax(demand - Q, 0) + co * pmax(Q - demand, 0)))
best <- grid[which.min(exp_cost)]
viz_lines(grid, `Expected cost` = exp_cost, xlab = "stock ($ millions)", ylab = "expected cost ($ millions)",
          title = sprintf("Expected cost is lowest near %s", format(best, big.mark = ",")))

#| **The recommendation, in one line a manager can act on.** Compare the newsvendor stock with simply stocking the point forecast.
cost_at <- function(Q) mean(cu * pmax(demand - Q, 0) + co * pmax(Q - demand, 0))
viz_kpi(`Stock ($ millions)` = round(stock), `Service level` = sprintf("%.0f%%", 100 * critical_ratio),
        `Safety stock ($ millions)` = round(stock - point),
        `Expected saving vs. stocking the forecast ($ millions)` = round(cost_at(point) - cost_at(stock)),
        title = "December 2026 stocking recommendation")
round(c(cost_if_stock_forecast = cost_at(point), cost_if_newsvendor = cost_at(stock)), 1)
