#| **Same data and model**, fitted on everything through the latest month.
import statsmodels.formula.api as smf      # R-style regression formulas
# one column per series: vehicle sales (mn, SAAR), gas ($/gal), unemployment (%), mortgage rate (%)
d = pd.concat({"veh": fred("TOTALSA"), "gas": fred("GASREGW", to="month"),
               "un": fred("UNRATE"), "mr": fred("MORTGAGE30US", to="month")}, axis=1, sort=True)
d = d["1993-01":].dropna()                 # keep Jan 1993 onward, drop months missing any series
d["chip"] = d.index.year.isin([2021, 2022]).astype(int)   # chip-shortage dummy: 1 in 2021-2022, else 0
fit = smf.ols("veh ~ gas + un + mr + chip", data=d).fit()   # regression on all data
print(d.tail(1))                           # the latest month's values: our starting point

#| **Scenarios as tables of future driver values**, 12 months ahead. Baseline holds drivers flat; "Gas hits $5" ramps gas to $5.00 over three months; "Squeeze" adds rising unemployment (to 5.5%) and 8% mortgage rates.
h = 12; now = d.iloc[-1]                   # 12 months ahead; now = last row of the data
# dates of the next 12 months ("MS" = month start), beginning the month after the data end
idx = pd.date_range(d.index[-1] + pd.offsets.MonthBegin(1), periods=h, freq="MS")
# helper: move from a to b in 3 equal monthly steps, then hold b (np.r_ joins the two pieces)
ramp = lambda a, b: np.r_[np.linspace(a, b, 4)[1:], np.full(h - 3, b)]
base = pd.DataFrame({"gas": now.gas, "un": now.un, "mr": now.mr, "chip": 0}, index=idx)   # drivers held flat
gas5 = base.assign(gas=ramp(now.gas, 5))   # .assign(): copy base, replacing the gas column
squeeze = gas5.assign(un=np.linspace(now.un, 5.5, h), mr=ramp(now.mr, 8))   # plus unemployment to 5.5%, rates to 8%

#| **One forecast per scenario**, with prediction intervals from `get_prediction()`.
def fc(x, alpha):                          # forecast + (1 - alpha) prediction interval, dated by idx
    return fit.get_prediction(x).summary_frame(alpha=alpha).set_index(idx)
f_base, f_gas5, f_sq = fc(base, .05), fc(gas5, .05), fc(squeeze, .05)   # 95% intervals for each scenario
# 2022+ history plus the three forecast paths ("mean" column = point forecast)
viz_compare(history=d.veh["2022":], Baseline=f_base["mean"], **{"Gas hits $5": f_gas5["mean"]},
            Squeeze=f_sq["mean"], title="$5 gas alone trims sales; a weaker job market hurts far more")
# average gap vs baseline over the 12 months, millions of cars (SAAR)
print("Average gap vs baseline:", round((f_gas5["mean"] - f_base["mean"]).mean(), 2), "(gas),",
      round((f_sq["mean"] - f_base["mean"]).mean(), 2), "(squeeze)")

#| **The fan for the gas scenario**, 80% and 95%. These intervals assume the driver path is known exactly, so they understate the real uncertainty.
f80 = fc(gas5, .20)                        # alpha = 0.20 gives the 80% interval
# arguments: history, point forecast, [80%, 95%] lower bounds, [80%, 95%] upper bounds
viz_forecast(d.veh, f_gas5["mean"], [f80["obs_ci_lower"], f_gas5["obs_ci_lower"]], [f80["obs_ci_upper"], f_gas5["obs_ci_upper"]],
             levels=("80%", "95%"), from_="2022-01-01", title="Even if gas is exactly $5, the 95% band spans about 5 million cars")
