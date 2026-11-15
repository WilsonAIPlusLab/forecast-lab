from statsmodels.tsa.seasonal import STL          # STL decomposition (seasonal-trend using LOESS)
retail = fred("RSXFSN", start=2005)                 # U.S. retail sales excl. food services, $ millions, NSA
# STL on log sales; these settings reproduce R's stl(s.window = 13, robust = TRUE)
fit = STL(np.log(retail), period=12, seasonal=13, robust=True, seasonal_deg=0,
          seasonal_jump=2, trend_jump=3, low_pass_jump=2).fit(inner_iter=1, outer_iter=15)
seasonal = fit.seasonal                             # seasonal component, on the log scale

# 1. Seasonally adjust: remove the seasonal component on the log scale, then go back to dollars
sa = np.exp(np.log(retail) - seasonal)              # subtract in logs, np.exp() back to $ millions

# 2. Month-over-month growth of the ADJUSTED series, November -> December 2025, in percent
growth = 100 * (sa["2025-12-01"] / sa["2025-11-01"] - 1)   # new / old - 1: December over November
print(growth)

# 3. For comparison: the raw (NSA) jump that a headline might report
print(100 * (retail["2025-12-01"] / retail["2025-11-01"] - 1))   # raw % change, December over November
