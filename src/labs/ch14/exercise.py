import warnings; warnings.filterwarnings("ignore")   # hide optimizer warnings
from statsmodels.tsa.holtwinters import ExponentialSmoothing   # Holt-Winters exponential smoothing
y = fred("MRTSSM445USN", start=2010) / 1000   # grocery (food & beverage store) sales, $ billions per month, NOT seasonally adjusted
y.index.freq = "MS"                           # tell pandas the data are monthly (month-start dates)
h, n = 12, len(y)                             # forecast 12 months ahead; n = number of months
origins = range(n - 48, n - 3, 4)             # 12 forecast origins over the last four years

# The method: damped-trend Holt-Winters with multiplicative seasonality, re-estimated every time it is called
def fit_fc(x):                                # x = data up to an origin; returns h forecasts
    return ______(x, trend="add", damped_trend=True, seasonal="mul",   # blank: the class imported above
                                seasonal_periods=12).fit(use_brute=False).forecast(h)

# 1. Rolling-origin errors: at each origin, fit on the data up to that origin only
errs = np.full((len(origins), h), np.nan)     # empty table: one row per origin, one column per horizon
for r, o in enumerate(origins):               # r = row number, o = origin position
    f = fit_fc(y.iloc[:o]).values             # .iloc[:o] = the first o months only
    for j in range(min(h, n - o)):            # skip horizons past the end of the data (they stay NaN)
        errs[r, j] = y.iloc[o + j] - f[j]     # error = actual minus forecast
mae1 = np.nanmean(np.abs(errs[:, 0]))                           # typical miss, 1 month ahead
# blank below: the column index of the 12-month horizon (remember where Python starts counting)
q = np.nanquantile(errs[:, ______], [0.10, 0.90])               # errors at the 12-month horizon

# 2. Final forecast from all the data, with the 80% range from past errors
fc = fit_fc(y)                                # re-fit on every month we have
point = fc.iloc[-1]                           # the forecast 12 months out (last value)
lo80, hi80 = point + q[0], point + q[1]       # forecast + 10th / 90th-percentile errors

# 3. Generate the summary: the last slot is the typical one-month-ahead miss
# f-strings fill each {...}: :.1f = 1 decimal place, :%B %Y = month name and year
summary_text = (f"We expect U.S. grocery store sales (not seasonally adjusted) to be about ${point:.1f} billion in "
                f"{fc.index[-1]:%B %Y} (80% range ${lo80:.1f} to ${hi80:.1f} billion). Over 12 forecast origins in the past "
                f"four years, the model's typical one-month-ahead miss was ${______:.1f} billion.")
print(summary_text)
