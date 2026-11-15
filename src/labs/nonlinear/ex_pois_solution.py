# Is the morning rush Poisson? Rentals at 8 a.m. on working days.
import statsmodels.api as sm               # model families
import statsmodels.formula.api as smf      # R-style formulas
hourly = pd.read_csv("data/bike_hour.csv")   # one row per hour
rush = hourly[(hourly["hr"] == 8) & (hourly["workingday"] == 1)]   # keep 8 a.m. on working days only

# 1. Fit a Poisson regression of the count on the year and the temperature
m = smf.glm("cnt ~ yr + temp", rush, family=sm.families.Poisson()).fit()   # Poisson regression (log link)

# 2. Dispersion statistic: Pearson chi-square / residual df
dispersion = m.pearson_chi2 / m.df_resid   # sum of squared Pearson residuals / residual df
print(dispersion)                          # about 1 if the Poisson assumption holds
