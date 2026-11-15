#| **Same data and model**, fitted on everything through the latest month.
import statsmodels.formula.api as smf
d = pd.concat({"veh": fred("TOTALSA"), "gas": fred("GASREGW", to="month"),
               "un": fred("UNRATE"), "mr": fred("MORTGAGE30US", to="month")}, axis=1, sort=True)
d = d["1993-01":].dropna()
d["chip"] = d.index.year.isin([2021, 2022]).astype(int)
fit = smf.ols("veh ~ gas + un + mr + chip", data=d).fit()
print(d.tail(1))

#| **Scenarios as tables of future driver values**, 12 months ahead. Baseline holds drivers flat; "Gas hits $5" ramps gas to $5.00 over three months; "Squeeze" adds rising unemployment (to 5.5%) and 8% mortgage rates.
h = 12; now = d.iloc[-1]
idx = pd.date_range(d.index[-1] + pd.offsets.MonthBegin(1), periods=h, freq="MS")
ramp = lambda a, b: np.r_[np.linspace(a, b, 4)[1:], np.full(h - 3, b)]
base = pd.DataFrame({"gas": now.gas, "un": now.un, "mr": now.mr, "chip": 0}, index=idx)
gas5 = base.assign(gas=ramp(now.gas, 5))
squeeze = gas5.assign(un=np.linspace(now.un, 5.5, h), mr=ramp(now.mr, 8))

#| **One forecast per scenario**, with prediction intervals from `get_prediction()`.
def fc(x, alpha):
    return fit.get_prediction(x).summary_frame(alpha=alpha).set_index(idx)
f_base, f_gas5, f_sq = fc(base, .05), fc(gas5, .05), fc(squeeze, .05)
viz_compare(history=d.veh["2022":], Baseline=f_base["mean"], **{"Gas hits $5": f_gas5["mean"]},
            Squeeze=f_sq["mean"], title="$5 gas alone trims sales; a weaker job market hurts far more")
print("Average gap vs baseline:", round((f_gas5["mean"] - f_base["mean"]).mean(), 2), "(gas),",
      round((f_sq["mean"] - f_base["mean"]).mean(), 2), "(squeeze)")

#| **The fan for the gas scenario**, 80% and 95%. These intervals assume the driver path is known exactly, so they understate the real uncertainty.
f80 = fc(gas5, .20)
viz_forecast(d.veh, f_gas5["mean"], [f80["obs_ci_lower"], f_gas5["obs_ci_lower"]], [f80["obs_ci_upper"], f_gas5["obs_ci_upper"]],
             levels=("80%", "95%"), from_="2022-01-01", title="Even if gas is exactly $5, the 95% band spans about 5 million cars")
