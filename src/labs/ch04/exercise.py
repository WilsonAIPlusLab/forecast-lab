import statsmodels.formula.api as smf
d = pd.concat({"veh": fred("TOTALSA"), "gas": fred("GASREGW", to="month"),
               "un": fred("UNRATE"), "mr": fred("MORTGAGE30US", to="month")}, axis=1, sort=True)
d = d["1993-01":].dropna()
d["chip"] = d.index.year.isin([2021, 2022]).astype(int)
fit = smf.ols("veh ~ gas + un + mr + chip", data=d).fit()
now = d.iloc[-1]   # the latest month: October 2026

# 1. Two scenarios: everything at today's values, except the mortgage rate
today    = pd.DataFrame({"gas": [now.gas], "un": [now.un], "mr": [now.mr], "chip": [0]})
low_rate = pd.DataFrame({"gas": [now.gas], "un": [now.un], "mr": [______], "chip": [0]})   # rates fall to 5%

# 2. Predicted sales with 95% prediction intervals
p_today = fit.get_prediction(today).summary_frame(alpha=0.05)
p_low   = fit.get_prediction(______).summary_frame(alpha=0.05)
print(pd.concat({"today": p_today, "rates at 5%": p_low})[["mean", "obs_ci_lower", "obs_ci_upper"]].round(3))

# 3. How many more cars (millions, SAAR) does the model expect at 5%?
gap = p_low["mean"].iloc[0] - p_today["mean"].iloc[0]
gap
