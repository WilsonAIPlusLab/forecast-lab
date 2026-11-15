import warnings; warnings.filterwarnings("ignore")
from statsmodels.tsa.holtwinters import ExponentialSmoothing
y = fred("MRTSSM445USN", start=2010) / 1000   # grocery (food & beverage store) sales, $ billions per month, NOT seasonally adjusted
y.index.freq = "MS"
h, n = 12, len(y)
origins = range(n - 48, n - 3, 4)             # 12 forecast origins over the last four years

# The method: damped-trend Holt-Winters with multiplicative seasonality, re-estimated every time it is called
def fit_fc(x):
    return ______(x, trend="add", damped_trend=True, seasonal="mul",
                                seasonal_periods=12).fit(use_brute=False).forecast(h)

# 1. Rolling-origin errors: at each origin, fit on the data up to that origin only
errs = np.full((len(origins), h), np.nan)
for r, o in enumerate(origins):
    f = fit_fc(y.iloc[:o]).values
    for j in range(min(h, n - o)):
        errs[r, j] = y.iloc[o + j] - f[j]
mae1 = np.nanmean(np.abs(errs[:, 0]))                           # typical miss, 1 month ahead
q = np.nanquantile(errs[:, ______], [0.10, 0.90])               # errors at the 12-month horizon

# 2. Final forecast from all the data, with the 80% range from past errors
fc = fit_fc(y)
point = fc.iloc[-1]
lo80, hi80 = point + q[0], point + q[1]

# 3. Generate the summary: the last slot is the typical one-month-ahead miss
summary_text = (f"We expect U.S. grocery store sales (not seasonally adjusted) to be about ${point:.1f} billion in "
                f"{fc.index[-1]:%B %Y} (80% range ${lo80:.1f} to ${hi80:.1f} billion). Over 12 forecast origins in the past "
                f"four years, the model's typical one-month-ahead miss was ${______:.1f} billion.")
print(summary_text)
