# Your manager: "Claims and payrolls have a correlation of -0.97 over 2010-2019, so claims
# explain almost everything about jobs." Check that claim the way an analyst would.
claims = fred("ICSA", to="month").loc["2010-01":"2019-12"]   # initial claims a week, monthly average, SA
jobs   = fred("PAYEMS").loc["2010-01":"2019-12"]             # payroll jobs, thousands, SA
cpi    = fred("CPIAUCSL").loc["2010-01":"2019-12"]           # consumer price index, SA

# 1. Correlations in LEVELS (done for you): claims vs jobs, and CPI vs jobs
r_levels = pd.Series({"claims": claims.corr(jobs), "cpi": cpi.corr(jobs)})
print(r_levels.round(2))

# 2. A function that turns a monthly series into its % change from the previous month
# Blank: 100 times the first difference of the log of x (np.log, then .diff())
def g(x):
    return ______

# 3. The same correlations, but between monthly growth rates (.corr skips the missing first month)
# Blank: the monthly growth rate of the consumer price index
r_growth = pd.Series({"claims": g(claims).corr(g(jobs)), "cpi": ______.corr(g(jobs))})
print(r_growth.round(2))
