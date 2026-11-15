#| **Work on the log scale**, so December's percentage boost becomes a constant additive effect.
retail = fred("RSXFSN", start=2005)           # monthly retail sales, $ millions, NSA, from 2005
y = np.log(retail)                            # log scale: % seasonal effects become additive

#| **Fit STL with statsmodels.** `seasonal=13` matches R's `s.window = 13`. The other arguments (`seasonal_deg=0`, the three `*_jump` values, `inner_iter=1, outer_iter=15`) reproduce the exact settings R's `stl(..., robust = TRUE)` uses, so the two languages agree to many decimal places.
from statsmodels.tsa.seasonal import STL      # STL: seasonal-trend decomposition using LOESS smoothing
# period=12 months per cycle; robust=True down-weights outliers; the rest copies R's stl() settings
fit = STL(y, period=12, seasonal=13, robust=True, seasonal_deg=0,
          seasonal_jump=2, trend_jump=3, low_pass_jump=2).fit(inner_iter=1, outer_iter=15)
viz_decomp(fit, title="STL on log retail sales: COVID lands in the remainder")   # data, trend, seasonal, remainder panels

#| **Down-weighted months** (robustness weight below 0.3).
print([d.strftime("%Y-%m") for d in retail.index[fit.weights < 0.3]])   # list comprehension: those dates as "YYYY-MM"

#| **Seasonal factors**: `exp(seasonal)`, e.g. 1.12 = 12% above the underlying level.
factors = np.exp(fit.seasonal)                # exp() turns log seasonal effects into factors
print(factors["2025"].round(3))               # the 12 factors for 2025

#| **Seasonally adjust** by removing the seasonal component on the log scale.
sa = np.exp(y - fit.seasonal)                 # seasonally adjusted sales, $ millions

#| **Compare with Census's X-13 adjustment** of the same aggregate: retail & food services minus food services & drinking places.
official = fred("RSAFS", start=2005) - fred("RSFSDP", start=2005)   # Census SA retail excl. food services
# all from 2021 on
viz_ts(**{"Raw (NSA)": retail["2021":], "Our STL adjustment": sa["2021":], "Census SA (X-13)": official["2021":]},
       ylab="$ millions", title="Our homemade adjustment tracks the official one closely",
       subtitle="U.S. retail sales excl. food services, $ millions per month")

#| **Mean absolute gap, in percent.**
print(round(100 * (sa / official - 1).abs().mean(), 2))   # average absolute % gap, ours vs Census
