import statsmodels.formula.api as smf   # R-style regression formulas
# one column per series: vehicle sales (mn, SAAR), gas ($/gal), unemployment (%), mortgage rate (%)
d = pd.concat({"veh": fred("TOTALSA"), "gas": fred("GASREGW", to="month"),
               "un": fred("UNRATE"), "mr": fred("MORTGAGE30US", to="month")}, axis=1, sort=True)
d = d["1993-01":].dropna()   # keep Jan 1993 onward, drop months missing any series
d["chip"] = d.index.year.isin([2021, 2022]).astype(int)   # chip-shortage dummy: 1 in 2021-2022, else 0
fit = smf.ols("veh ~ gas + un + mr + chip", data=d).fit()   # the regression from the first lab, on all data
now = d.iloc[-1]   # the latest month: October 2026

# 1. Two scenarios: everything at today's values, except the mortgage rate
# each scenario is a one-row data frame of driver values; chip = 0 means no shortage
today    = pd.DataFrame({"gas": [now.gas], "un": [now.un], "mr": [now.mr], "chip": [0]})
# blank: the new mortgage rate, in percent
low_rate = pd.DataFrame({"gas": [now.gas], "un": [now.un], "mr": [______], "chip": [0]})   # rates fall to 5%

# 2. Predicted sales with 95% prediction intervals
# get_prediction().summary_frame(): forecast ('mean') and 95% prediction interval ('obs_ci_lower/upper')
p_today = fit.get_prediction(today).summary_frame(alpha=0.05)
# blank: the data frame that holds the second scenario
p_low   = fit.get_prediction(______).summary_frame(alpha=0.05)
# stack both scenarios and keep the forecast and the 95% prediction interval columns
print(pd.concat({"today": p_today, "rates at 5%": p_low})[["mean", "obs_ci_lower", "obs_ci_upper"]].round(3))

# 3. How many more cars (millions, SAAR) does the model expect at 5%?
gap = p_low["mean"].iloc[0] - p_today["mean"].iloc[0]   # low-rate forecast minus today's forecast
gap
