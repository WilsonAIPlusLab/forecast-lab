import statsmodels.api as sm                                   # OLS and add_constant
claims = fred("ICSA", to="month"); jobs = fred("PAYEMS")       # initial claims (monthly avg) and payrolls, SA
dj = jobs.diff()                       # jobs added each month, thousands
dcl = 100 * np.log(claims).diff()      # % change in claims

# An ADL(1, 1): jobs added depend on last month's jobs added,
# and on claims growth this month and last month
# .shift(1) = last month's value; then keep 1990-2019
D = pd.DataFrame({"dj": dj, "dj_1": dj.shift(1), "dcl_0": dcl, "dcl_1": dcl.shift(1)})["1990-01":"2019-12"]
fit = sm.OLS(D["dj"], sm.add_constant(D[["dj_1", "dcl_0", "dcl_1"]])).fit()   # add_constant adds the intercept
b = fit.params                         # coefficients, labelled const, dj_1 (phi), dcl_0, dcl_1
print(b.round(3))

# 1. Impact multiplier: the effect of claims growth on jobs added in the SAME month
# Blank: one element of b, picked by its label (which one is same-month claims growth?)
impact = ______

# 2. Long-run multiplier: (sum of the claims coefficients) / (1 - phi)
# Blank: the numerator; wrap a sum in parentheses so it is divided as a whole
long_run = ______ / (1 - b["dj_1"])

print(pd.Series({"impact": impact, "long_run": long_run}).round(1))
