import warnings; warnings.filterwarnings("ignore")   # hide optimizer warnings
from statsmodels.tsa.holtwinters import ExponentialSmoothing   # Holt-Winters exponential smoothing
y = fred("RSXFSN", start=2010) / 1000         # U.S. retail sales, $ billions per month, NOT seasonally adjusted
y.index.freq = "MS"                           # tell pandas the data are monthly (month-start dates)
f = ExponentialSmoothing(y, trend="add", damped_trend=True, seasonal="mul",
                         seasonal_periods=12).fit(use_brute=False).forecast(12)   # next 12 months, $ billions
fc = f.values                                 # plain numbers
months = f.index.strftime("%b %Y")            # labels such as "Dec 2026"

# Two comparisons a manager might hear
latest = y.iloc[-1]                           # the latest actual month
last_year = y.iloc[-______:].values           # blank: how many months back covers the same calendar months a year earlier
vs_latest = 100 * (fc / latest - 1)           # % change from the latest month: mixes in the seasonal pattern
vs_last_year = 100 * (fc / ______ - 1)        # blank: the values from the same months a year earlier

print(pd.DataFrame({"month": months, "forecast": fc.round(1), "vs_latest": vs_latest.round(1), "vs_last_year": vs_last_year.round(1)}))
total_growth = 100 * (fc.sum() / ______.sum() - 1)     # blank: the 12 actual months to compare the forecast total with
dec = list(months.str[:3]).index("Dec")       # position of December in the forecast
print(f"December sales should be about ${fc[dec]:.1f} billion, {vs_last_year[dec]:.1f}% above last December "
      f"(not {vs_latest[dec]:.0f}% above {y.index[-1]:%B}, which mostly reflects the holiday season). "
      f"Over the next 12 months as a whole, sales should run {total_growth:.1f}% above the last 12.")
