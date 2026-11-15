# Is the morning rush Poisson? Rentals at 8 a.m. on working days.
import statsmodels.api as sm               # model families
import statsmodels.formula.api as smf      # R-style formulas
hourly = pd.read_csv("data/bike_hour.csv")   # one row per hour
rush = hourly[(hourly["hr"] == 8) & (hourly["workingday"] == 1)]   # keep 8 a.m. on working days only

# 1. Fit a Poisson regression of the count on the year and the temperature
# blank: the name of the count-data family (capitalized class name)
m = smf.glm("cnt ~ yr + temp", rush, family=sm.families.______()).fit()

# 2. Dispersion statistic: Pearson chi-square / residual df
# blank: the fitted model's attribute holding the Pearson chi-square statistic
dispersion = m.______ / m.df_resid
print(dispersion)                          # about 1 if the Poisson assumption holds
