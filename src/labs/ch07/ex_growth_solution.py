# Your manager: "Claims and payrolls have a correlation of -0.97 over 2010-2019, so claims
# explain almost everything about jobs." Check that claim the way an analyst would.
claims = fred("ICSA", to="month").loc["2010-01":"2019-12"]   # initial claims a week, monthly average, SA
jobs   = fred("PAYEMS").loc["2010-01":"2019-12"]             # payroll jobs, thousands, SA
cpi    = fred("CPIAUCSL").loc["2010-01":"2019-12"]           # consumer price index, SA

# 1. Correlations in LEVELS: claims vs jobs, and CPI vs jobs
r_levels = pd.Series({"claims": claims.corr(jobs), "cpi": cpi.corr(jobs)})   # both close to -1 or +1: shared trends
print(r_levels.round(2))

# 2. A function that turns a monthly series into its % change from the previous month
def g(x):
    return 100 * np.log(x).diff()     # log difference x 100 = approximately the % change

# 3. The same correlations, but between monthly growth rates (.corr skips the missing first month)
r_growth = pd.Series({"claims": g(claims).corr(g(jobs)), "cpi": g(cpi).corr(g(jobs))})   # the trends are gone
print(r_growth.round(2))
