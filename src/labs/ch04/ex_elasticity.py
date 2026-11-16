# Your manager asks: "If gas prices rise 20%, by what percent will our sales change,
# holding jobs and interest rates fixed?" Answer with an elasticity.
import statsmodels.formula.api as smf      # R-style regression formulas
# one column per series: vehicle sales (mn, SAAR), gas ($/gal), unemployment (%), mortgage rate (%)
d = pd.concat({"veh": fred("TOTALSA"), "gas": fred("GASREGW", to="month"),
               "un": fred("UNRATE"), "mr": fred("MORTGAGE30US", to="month")}, axis=1, sort=True)
d = d["1993-01":].dropna()                 # keep Jan 1993 onward, drop months missing any series
d["chip"] = d.index.year.isin([2021, 2022]).astype(int)   # chip-shortage dummy: 1 in 2021-22, else 0

# 1. A log-log model for gas: log sales on log gas (other drivers stay in levels)
# blank: the gas price, transformed so its coefficient is an elasticity
fit_ll = smf.ols("np.log(veh) ~ ______ + un + mr + chip", data=d).fit()
b_gas = fit_ll.params.iloc[1]              # the gas elasticity (2nd coefficient, after the intercept)
print(round(b_gas, 4))

# 2. Rule of thumb: % change in sales = elasticity x % change in gas
pct_approx = b_gas * ______                # blank: the % rise in gas, as a number of percent

# 3. Exact version: sales are multiplied by (new gas / old gas) ** elasticity
pct_exact = 100 * (______ ** b_gas - 1)    # blank: the ratio new price / old price for a 20% rise
print(f"approx: {pct_approx:.3f}%   exact: {pct_exact:.3f}%")
