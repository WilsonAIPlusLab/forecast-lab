# Is the morning rush Poisson? Rentals at 8 a.m. on working days.
import statsmodels.api as sm
import statsmodels.formula.api as smf
hourly = pd.read_csv("data/bike_hour.csv")
rush = hourly[(hourly["hr"] == 8) & (hourly["workingday"] == 1)]

# 1. Fit a Poisson regression of the count on the year and the temperature
m = smf.glm("cnt ~ yr + temp", rush, family=sm.families.Poisson()).fit()

# 2. Dispersion statistic: Pearson chi-square / residual df
dispersion = m.pearson_chi2 / m.df_resid
print(dispersion)
