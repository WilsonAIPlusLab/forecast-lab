import warnings; warnings.filterwarnings("ignore")   # hide optimizer warnings
from statsmodels.tsa.holtwinters import ExponentialSmoothing   # Holt-Winters exponential smoothing
y = fred("RSXFSN", start=2010) / 1000         # U.S. retail sales, $ billions per month, NOT seasonally adjusted
y.index.freq = "MS"                           # tell pandas the data are monthly (month-start dates)
h, n = 12, len(y)                             # forecast 1 to 12 months ahead; n = number of months
origins = range(n - 48, n - 5, 6)             # 8 forecast origins, one every 6 months over four years

# Rolling-origin MAE of one forecasting function: re-fit at every origin on the data up to that origin only
def cv_mae(fc_fun):
    errs = []                                 # all absolute errors, every origin and horizon
    for o in origins:
        f = np.asarray(fc_fun(y.iloc[:o]))    # .iloc[:o] = the first o months only
        for j in range(min(h, n - o)):        # skip horizons past the end of the data
            errs.append(abs(y.iloc[o + j] - f[j]))   # absolute error = |actual - forecast|
    return np.mean(errs)                      # average absolute miss over all origins and horizons

def snaive(x):                                # same month last year: repeat the last 12 values
    return np.tile(x.values[-12:], 2)[:h]

def hw(x, seasonal):                          # damped-trend Holt-Winters; seasonal = "add" or "mul"
    return ExponentialSmoothing(x, trend="add", damped_trend=True, seasonal=seasonal,
                                seasonal_periods=12).fit(use_brute=False).forecast(h)

# The benchmark and two models that differ in ONE choice only: the type of seasonality
mae_snaive = cv_mae(snaive)                               # same month last year
mae_add = cv_mae(lambda x: hw(x, "add"))                  # seasonal swings of fixed size
mae_mul = cv_mae(lambda x: hw(x, "mul"))                  # swings that scale with the level

# The single change, judged by how much it lowers the error
gain = 100 * (1 - mae_mul / mae_add)          # % reduction in MAE from additive to multiplicative
print(pd.Series({"Seasonal naive": mae_snaive, "Additive": mae_add, "Multiplicative": mae_mul, "Gain (%)": gain}).round(3))
print(f"Switching from additive to multiplicative seasonality, with nothing else changed, cut the typical miss "
      f"from ${mae_add:.1f} to ${mae_mul:.1f} billion ({gain:.0f}%). Both beat the seasonal naive benchmark (${mae_snaive:.1f} billion).")
