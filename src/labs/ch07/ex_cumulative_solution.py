# Your manager asks: "If weekly claims jump 10% this month and stay there, how many fewer
# jobs will we see over this month and the next two, in total?"
import statsmodels.api as sm                                   # OLS and add_constant
claims = fred("ICSA", to="month"); jobs = fred("PAYEMS")       # initial claims (monthly avg) and payrolls, SA
dj = jobs.diff()                       # jobs added each month, thousands
dcl = 100 * np.log(claims).diff()      # % change in claims

# ADL(1, 1): jobs added depend on last month's jobs added and on claims growth now and last month
# .shift(1) = last month's value; then keep 1990-2019
D = pd.DataFrame({"dj": dj, "dj_1": dj.shift(1), "dcl_0": dcl, "dcl_1": dcl.shift(1)})["1990-01":"2019-12"]
b = sm.OLS(D["dj"], sm.add_constant(D[["dj_1", "dcl_0", "dcl_1"]])).fit().params
phi, b0, b1 = b["dj_1"], b["dcl_0"], b["dcl_1"]   # persistence of job gains; claims effect now; claims effect a month later

# Dynamic multipliers for a 1% rise in claims that lasts (thousands of jobs added vs normal)
m0 = b0                                # month 0: the impact multiplier
m1 = b1 + phi * m0                     # month 1: lagged claims effect + echo of month 0
m2 = phi * m1                          # month 2: only the echo of month 1 is left

# Cumulative effect of a 10% jump over months 0, 1 and 2 (thousands of jobs)
cum3 = 10 * (m0 + m1 + m2)             # 10 = size of the jump, in %
print(pd.Series({"m0": m0, "m1": m1, "m2": m2, "cum3": cum3}).round(1))
