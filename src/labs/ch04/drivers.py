#| **Load the demand series and three drivers.** Vehicle sales are seasonally adjusted, millions of units at an annual rate (SAAR). Weekly gas prices and mortgage rates are averaged to months with `to="month"`. The October 2025 unemployment rate was never published (government shutdown); `fred()` fills that one month by linear interpolation and prints a note.
import statsmodels.formula.api as smf
d = pd.concat({"veh": fred("TOTALSA"), "gas": fred("GASREGW", to="month"),
               "un": fred("UNRATE"), "mr": fred("MORTGAGE30US", to="month")}, axis=1, sort=True)
d = d["1993-01":].dropna()

#| **Add the event dummy**: 1 during the 2021–2022 semiconductor shortage, 0 otherwise.
d["chip"] = d.index.year.isin([2021, 2022]).astype(int)
viz_ts(**{"Vehicle sales (mn, SAAR)": d.veh, "Gas ($/gal)": d.gas, "Unemployment (%)": d.un,
          "Mortgage rate (%)": d.mr}, facet=True, recessions=True, title="Car sales fall when unemployment jumps")

#| **OLS without and with the dummy.** `smf.ols` takes the same formula syntax as R's `lm()`. Each slope is the change in sales (millions, SAAR) for a one-unit change in that driver, holding the others constant.
m0 = smf.ols("veh ~ gas + un + mr", data=d).fit()
m1 = smf.ols("veh ~ gas + un + mr + chip", data=d).fit()
print(f"R-squared: {m0.rsquared:.3f} without the dummy, {m1.rsquared:.3f} with it")
print(m1.summary().tables[1])

#| **Residual autocorrelation.** Tall bars beyond the band mean this month's miss predicts next month's miss, so the usual standard errors are too small.
viz_acf(m1.resid, lag_max=24, title="The model's misses persist for months")

#| **Newey–West (HAC) standard errors.** statsmodels needs a lag length; we use 12 months. R's `NeweyWest()` picks its own bandwidth and pre-whitens, so the standard errors differ from the R tab. For gas, unemployment and the mortgage rate the conclusion is the same. For the **chip** dummy it is not: here its t-statistic is about −3.2, while R's automatic bandwidth gives about −1.8. A dummy that covers 24 consecutive months is fragile evidence, and its significance depends on how you correct for autocorrelation.
nw = smf.ols("veh ~ gas + un + mr + chip", data=d).fit(cov_type="HAC", cov_kwds={"maxlags": 12})
tab = pd.DataFrame({"Estimate": m1.params, "OLS s.e.": m1.bse, "Newey-West s.e.": nw.bse, "NW t": nw.tvalues})
print(tab.round(3))
viz_table(tab, digits=3, title="Vehicle sales drivers, 1993 to 2026 (millions of units, SAAR)")

#| **Elasticities from logs.** In `log(veh) ~ log(gas)`, the gas coefficient is the % change in sales for a 1% change in gas prices.
m_log = smf.ols("np.log(veh) ~ np.log(gas) + un + mr + chip", data=d).fit()
print(m_log.params.round(4))
