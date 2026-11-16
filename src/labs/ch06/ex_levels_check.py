# Hidden check for ex_levels.
from statsmodels.tsa.arima.model import ARIMA as _ARIMA
_p = fred("PCEPILFE", start="2000-01-01", quiet=True)
_g = (100 * np.log(_p).diff()).dropna()
_f = _ARIMA(_g, order=(1, 0, 1), trend="c").fit().forecast(12).to_numpy()
_last = float(_p.iloc[-1])
_lv = _last * np.exp(np.cumsum(_f) / 100)
_ok = False
try:
    _ok = len(level) == 12 and np.allclose(np.asarray(level, dtype=float), _lv, atol=1e-6) and abs(float(infl_12) - 100 * (_lv[11] / _last - 1)) < 1e-6
except Exception:
    pass
check_that(_ok,
  f"Right: the index is forecast at {_lv[11]:.2f} in September 2027 (from {_last:.2f}), so 12-month core inflation is {100 * (_lv[11] / _last - 1):.2f}%. You undid the two transformations in reverse order: np.cumsum() undoes the difference, np.exp() undoes the log. That is what a forecasting package does for you when you fit the same model to log prices with d = 1. Also notice that 12-month inflation is exp(sum of the 12 monthly log changes) - 1. (Chapter 10 explains why exp() of a log forecast is a median, not a mean.)",
  "Undo the transformations in reverse order: first a running total of the monthly log changes, np.cumsum(); then np.exp() to undo the log. The 12-month rate compares the September 2027 level with the latest observed level, last.")
