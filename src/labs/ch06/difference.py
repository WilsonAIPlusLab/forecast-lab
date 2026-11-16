#| **Two series that have nothing to do with each other.** Food prices (CPI food, index 1982–84 = 100, SA) and e-commerce sales ($ millions, SA), monthly, 2000 to 2019. We stop before 2020 so the pandemic does not drive the story. Both trend up for twenty years, for completely different reasons.
import statsmodels.api as sm
food = fred("CPIUFDSL", start="2000-01-01", end="2019-12-01")       # CPI food price index, 1982-84 = 100
ecom = fred("MRTSSM4541USS", start="2000-01-01", end="2019-12-01")  # online retail sales, $ millions
lev = sm.OLS(np.log(food), sm.add_constant(np.log(ecom))).fit()     # regression in levels (logs); add_constant = intercept
print(round(lev.rsquared, 3))                # share of variation "explained": suspiciously close to 1

#| **The same regression on growth rates.** `np.log(x).diff()` is the monthly change in logs, and multiplying by 100 makes it (almost exactly) a percent change. Once the shared upward trend is removed, the "relationship" vanishes. The levels regression was measuring two trends, not a link.
g_food = (100 * np.log(food).diff()).dropna()   # monthly food inflation, % (not annualized); drop the first NaN
g_ecom = (100 * np.log(ecom).diff()).dropna()   # monthly e-commerce growth, %
grw = sm.OLS(g_food, sm.add_constant(g_ecom)).fit()   # regression in growth rates
# R-squared and the slope's t-statistic (.iloc[1] = the slope, after the constant), levels vs growth rates
print(pd.DataFrame({"R2": [lev.rsquared, grw.rsquared], "t_slope": [lev.tvalues.iloc[1], grw.tvalues.iloc[1]]},
                   index=["levels", "growth"]).round(3))
viz_scatter(g_ecom, g_food, xlab="e-commerce growth, % per month", ylab="food inflation, % per month",
            title="In growth rates, the two series are unrelated")

#| **Log + difference = growth rate.** For core PCE in September 2026, compare the exact percent change with 100 times the log difference. They agree to two decimals, because $\ln(1+g) \approx g$ when $g$ is small. Over 12 months the log changes simply **add up**, which is why we model inflation as a log difference.
p = fred("PCEPILFE", start="2024-01-01")     # recent core PCE data
lp = np.log(p)                               # log price level
print({"pct_change": round(float(100 * (p.iloc[-1] / p.iloc[-2] - 1)), 4),   # exact % change from the month before
       "log_diff": round(float(100 * (lp.iloc[-1] - lp.iloc[-2])), 4),        # log difference x 100: nearly identical
       "annualized": round(float(1200 * (lp.iloc[-1] - lp.iloc[-2])), 4)})    # x 12 more: "% per year" pace
# 12-month inflation two ways: the sum of the last 12 monthly log changes, then converted back to a % change
sum12 = lp.diff().iloc[-12:].sum()           # .iloc[-12:] = the last 12 monthly log changes
print({"sum_of_12_log_changes": round(float(100 * sum12), 4), "yoy_pct": round(float(100 * (np.exp(sum12) - 1)), 4),
       "check": round(float(100 * (p.iloc[-1] / p.iloc[-13] - 1)), 4)})

#| **Seasonal difference of a log = year-over-year growth.** Retail sales are *not* seasonally adjusted, so December towers over other months. `.diff(12)` subtracts the same month a year earlier: the seasonal pattern cancels, and what is left is (almost exactly) the 12-month growth rate.
rs = fred("RSXFSN", start="2010-01-01", end="2019-12-01")   # retail sales, $ millions, NSA
d12 = (100 * np.log(rs).diff(12)).dropna()   # seasonal log difference, x 100
yoy = (100 * rs.pct_change(12)).dropna()     # exact YoY % change
viz_ts(ylab="%", title="A seasonal difference of logs is the year-over-year growth rate",
       **{"Seasonal log difference x 100": d12, "YoY % change": yoy})

#| **How many differences? Look at the spread and the lag-1 autocorrelation.** For the unemployment rate (1990–2019) we compare d = 0, 1 and 2. A rule of thumb from Robert Nau (Duke): the right d usually has the **smallest standard deviation**, and a lag-1 autocorrelation of **−0.5 or below** warns that you went one difference too far.
from statsmodels.tsa.stattools import acf
u = fred("UNRATE", start="1990-01-01", end="2019-12-01")   # unemployment rate, %, SA
cand = {"d = 0": u, "d = 1": u.diff().dropna(), "d = 2": u.diff().diff().dropna()}   # 0, 1 and 2 differences
# for each candidate: standard deviation and lag-1 autocorrelation (acf(...)[1] is lag 1)
tab = pd.DataFrame({k: {"sd": x.std(), "lag1_acf": acf(x, nlags=1)[1]} for k, x in cand.items()}).T
print(tab.round(3))
viz_table(tab, digits=3, highlight=["sd"],
          title="One difference is enough: d = 2 has a larger spread and a lag-1 ACF of -0.57")
