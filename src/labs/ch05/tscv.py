#| **Pre-COVID retail sales**, 2012 to 2019, $ millions, NSA.
import warnings; warnings.filterwarnings("ignore")   # hide optimizer warnings
from statsmodels.tsa.holtwinters import ExponentialSmoothing
retail = fred("RSXFSN", start=2012, end="2019-12-01")   # Jan 2012 to Dec 2019 (96 months)
y = retail.values                          # plain NumPy array of the sales numbers

#| **Rolling-origin cross-validation by hand**, as in Chapter 3. At each origin we re-fit an additive-trend, multiplicative-season model (the ETS(M,A,M) point forecasts come from the same recursions) and forecast 1 to 12 months ahead. statsmodels fits by least squares, R's `ets()` by maximum likelihood, so the numbers differ somewhat from the R tab.
H, INITIAL = 12, 72                        # forecast 1-12 months ahead; first origin uses 72 months (6 years)
def f_ets(tr, h):                          # fit Holt-Winters (mult.) on the data so far, forecast h months
    return ExponentialSmoothing(tr, trend="add", seasonal="mul", seasonal_periods=12,
                                initialization_method="estimated").fit().forecast(h)
def f_snaive(tr, h):                       # seasonal naive: repeat the last 12 months
    return np.array([tr[-12 + (i % 12)] for i in range(h)])

def tscv(method):                          # returns a matrix of errors: one row per origin, one column per horizon
    errs = np.full((len(y), H), np.nan)    # start with all missing (NaN)
    for o in range(INITIAL + 1, len(y)):   # same origins as R tsCV(initial = 72)
        f = method(y[:o], H)               # fit on the first o months only, forecast H months
        for k in range(H):
            if o + k < len(y):             # only where the actual value exists
                errs[o, k] = y[o + k] - f[k]   # error = actual - forecast
    return errs
e_ets, e_snaive = tscv(f_ets), tscv(f_snaive)

#| **MAE by horizon**, and the error-by-horizon chart.
# np.nanmean(..., axis=0): average down each column (horizon), ignoring missing values
mae = pd.DataFrame({"ETS": np.nanmean(np.abs(e_ets), axis=0),
                    "Seasonal naive": np.nanmean(np.abs(e_snaive), axis=0)}, index=range(1, 13))
print(mae.round(0).T)                      # rows = methods, columns = months ahead
viz_lines(range(1, 13), ETS=mae["ETS"], **{"Seasonal naive": mae["Seasonal naive"]}, xlab="months ahead",
          ylab="MAE ($ millions)", zero=True, title="ETS beats seasonal naive at every horizon")   # y-axis starts at 0
