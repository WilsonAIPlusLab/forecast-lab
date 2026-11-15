from statsmodels.tsa.seasonal import STL
retail = fred("RSXFSN", start=2005)                 # U.S. retail sales excl. food services, $ millions, NSA
fit = STL(np.log(retail), period=12, seasonal=13, robust=True, seasonal_deg=0,
          seasonal_jump=2, trend_jump=3, low_pass_jump=2).fit(inner_iter=1, outer_iter=15)
seasonal = fit.seasonal                             # seasonal component, on the log scale

# 1. Seasonally adjust: remove the seasonal component on the log scale, then go back to dollars
sa = np.exp(np.log(retail) - ______)

# 2. Month-over-month growth of the ADJUSTED series, November -> December 2025, in percent
growth = 100 * (sa["2025-12-01"] / ______ - 1)
print(growth)

# 3. For comparison: the raw (NSA) jump that a headline might report
print(100 * (retail["2025-12-01"] / retail["2025-11-01"] - 1))
