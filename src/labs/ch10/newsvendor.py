#| **The decision.** Plan December merchandise for U.S. clothing stores (`MRTSSM448USN`, $ millions, NSA), fitting on data since January 2022. Stock is valued at retail, in the same $ millions as sales. R's `ets()` picks an additive model, ETS(A,A,A), for this window, so we fit the same one. With less than five years of data, statsmodels' default way of estimating the starting values gets stuck in a poor solution here; `initialization_method="heuristic"` (starting values from the first two years) gives a fit very close to R's.
import warnings; warnings.filterwarnings("ignore")   # hide statsmodels fitting warnings
from statsmodels.tsa.exponential_smoothing.ets import ETSModel   # exponential smoothing (ETS)
clothing = fred("MRTSSM448USN", start=2022)   # monthly clothing-store sales, $ millions, not seasonally adjusted
last = clothing.index[-1]                     # date of the last observation
h = (2026 - last.year) * 12 + (12 - last.month)          # months ahead to December 2026
# ETS(A,A,A): additive error, trend and 12-month seasonality
fit = ETSModel(clothing, error="add", trend="add", seasonal="add", seasonal_periods=12,
              initialization_method="heuristic").fit(disp=False)
h                                             # forecast horizon in months

#| **A demand distribution.** Keep the December value from each of 5,000 simulated futures.
np.random.seed(2026)                          # fix the random draws so results repeat exactly
# last row = December 2026, one value per path
demand = fit.simulate(h, repetitions=5000, anchor="end").iloc[-1].values
point = fit.forecast(h).iloc[-1]              # the usual single-number (point) forecast for December
print(round(point), np.percentile(demand, [5, 50, 95]).round())   # point forecast vs. 5th/50th/95th percentiles

#| **Costs of being wrong**: $0.60 lost per $1 of unmet demand, $0.25 lost per $1 of leftover stock (assumptions for the example).
cu, co = 0.60, 0.25                           # underage cost, overage cost

#| **The newsvendor rule.** Stock the demand quantile at the critical ratio $c_u/(c_u+c_o) \approx 0.71$.
critical_ratio = cu / (cu + co)               # newsvendor critical ratio = target service level
stock = np.quantile(demand, critical_ratio)   # optimal stock: that quantile of simulated demand
# ratio, stock, safety stock (stock minus point forecast)
print(round(critical_ratio, 3), round(stock), round(stock - point))
# histogram of simulated demand
viz_custom("ch10-hist", values=demand.tolist(), bins=40, xlab="December 2026 sales ($ millions)",
           markers=[dict(x=point, label="Point forecast"), dict(x=stock, label="Optimal stock")],
           title="Stock above the point forecast because running out costs more")

#| **Brute-force check.** The expected cost is lowest at the critical-ratio quantile.
grid = np.arange(38000, 43001, 50)            # candidate stock levels 38,000 to 43,000, $ millions
# expected cost of stocking Q: np.maximum(x, 0) keeps only positive parts (shortage or leftover)
cost_at = lambda Q: np.mean(cu * np.maximum(demand - Q, 0) + co * np.maximum(Q - demand, 0))
exp_cost = np.array([cost_at(Q) for Q in grid])   # expected cost at every grid level
best = grid[exp_cost.argmin()]                # stock level with the lowest expected cost
viz_lines(grid, **{"Expected cost": exp_cost}, xlab="stock ($ millions)", ylab="expected cost ($ millions)",
          title=f"Expected cost is lowest near {best:,}")   # {best:,} adds thousands commas

#| **The recommendation.**
viz_kpi(title="December 2026 stocking recommendation", **{"Stock ($ millions)": round(stock), "Service level": f"{100 * critical_ratio:.0f}%",
        "Safety stock ($ millions)": round(stock - point),
        "Expected saving vs. stocking the forecast ($ millions)": round(cost_at(point) - cost_at(stock))})
