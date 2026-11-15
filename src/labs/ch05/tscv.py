#| **Pre-COVID retail sales**, 2012 to 2019, $ millions, NSA.
import warnings; warnings.filterwarnings("ignore")
from statsmodels.tsa.holtwinters import ExponentialSmoothing
retail = fred("RSXFSN", start=2012, end="2019-12-01")
y = retail.values

#| **Rolling-origin cross-validation by hand**, as in Chapter 3. At each origin we re-fit an additive-trend, multiplicative-season model (the ETS(M,A,M) point forecasts come from the same recursions) and forecast 1 to 12 months ahead. statsmodels fits by least squares, R's `ets()` by maximum likelihood, so the numbers differ somewhat from the R tab.
H, INITIAL = 12, 72
def f_ets(tr, h):
    return ExponentialSmoothing(tr, trend="add", seasonal="mul", seasonal_periods=12,
                                initialization_method="estimated").fit().forecast(h)
def f_snaive(tr, h):
    return np.array([tr[-12 + (i % 12)] for i in range(h)])

def tscv(method):
    errs = np.full((len(y), H), np.nan)
    for o in range(INITIAL + 1, len(y)):   # same origins as R tsCV(initial = 72)
        f = method(y[:o], H)
        for k in range(H):
            if o + k < len(y):
                errs[o, k] = y[o + k] - f[k]
    return errs
e_ets, e_snaive = tscv(f_ets), tscv(f_snaive)

#| **MAE by horizon**, and the error-by-horizon chart.
mae = pd.DataFrame({"ETS": np.nanmean(np.abs(e_ets), axis=0),
                    "Seasonal naive": np.nanmean(np.abs(e_snaive), axis=0)}, index=range(1, 13))
print(mae.round(0).T)
viz_lines(range(1, 13), ETS=mae["ETS"], **{"Seasonal naive": mae["Seasonal naive"]}, xlab="months ahead",
          ylab="MAE ($ millions)", zero=True, title="ETS beats seasonal naive at every horizon")
