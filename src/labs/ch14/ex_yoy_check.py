# Hidden grader: recomputes the forecast and the like-with-like comparisons, then checks the student's values.
_f = ExponentialSmoothing(y, trend="add", damped_trend=True, seasonal="mul", seasonal_periods=12).fit(use_brute=False).forecast(12).values
_ly = y.iloc[-12:].values; _v = 100 * (_f / _ly - 1); _tg = 100 * (_f.sum() / _ly.sum() - 1)
_vl = 100 * (_f / y.iloc[-1] - 1)
try:
    _ok = len(vs_last_year) == 12 and bool(np.allclose(list(vs_last_year) + [total_growth], list(_v) + [_tg], rtol=1e-6))
except Exception:
    _ok = False
check_that(_ok,
    f"Measured against the latest month, the forecasts swing from {_vl.min():+.0f}% to {_vl.max():+.0f}%: that is the calendar talking, "
    f"not the economy. Measured against the same month a year earlier they sit between {_v.min():+.1f}% and {_v.max():+.1f}%, and the next 12 months "
    f"as a whole are {_tg:+.1f}% on the last 12. For data that are not seasonally adjusted, always compare like with like: same month last year, or 12-month totals.",
    "A number is off. Check: last_year holds the last 12 actual months, y.iloc[-12:].values; vs_last_year divides the forecast by last_year; total_growth compares fc.sum() with last_year.sum().")
