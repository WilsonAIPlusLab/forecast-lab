import statsmodels.api as sm
claims = fred("ICSA", to="month"); jobs = fred("PAYEMS")
dj = jobs.diff()                       # jobs added each month, thousands
dcl = 100 * np.log(claims).diff()      # % change in claims

# An ADL(1, 1): jobs added depend on last month's jobs added,
# and on claims growth this month and last month
D = pd.DataFrame({"dj": dj, "dj_1": dj.shift(1), "dcl_0": dcl, "dcl_1": dcl.shift(1)})["1990-01":"2019-12"]
fit = sm.OLS(D["dj"], sm.add_constant(D[["dj_1", "dcl_0", "dcl_1"]])).fit()
b = fit.params
print(b.round(3))

# 1. Impact multiplier: the effect of claims growth on jobs added in the SAME month
impact = b["dcl_0"]

# 2. Long-run multiplier: (sum of the claims coefficients) / (1 - phi)
long_run = (b["dcl_0"] + b["dcl_1"]) / (1 - b["dj_1"])

print(pd.Series({"impact": impact, "long_run": long_run}).round(1))
