# Hidden grader: recomputes the benchmark and multiplicative MAEs and the gain, then checks the student's values.
def _cv(fun):
    _e = []
    for _o in range(len(y) - 48, len(y) - 5, 6):
        _f = np.asarray(fun(y.iloc[:_o]))
        for _j in range(min(12, len(y) - _o)):
            _e.append(abs(y.iloc[_o + _j] - _f[_j]))
    return np.mean(_e)
_sn = _cv(lambda x: np.tile(x.values[-12:], 2)[:12])
_mu = _cv(lambda x: ExponentialSmoothing(x, trend="add", damped_trend=True, seasonal="mul", seasonal_periods=12).fit(use_brute=False).forecast(12))
try:
    _g = 100 * (1 - _mu / mae_add)
    _mae_ok = bool(np.allclose([mae_snaive, mae_mul], [_sn, _mu], rtol=1e-6))
    _ok = _mae_ok and bool(np.isclose(gain, _g, rtol=1e-6))
except Exception:
    _mae_ok = _ok = False
check_that(_ok,
    f"One change (additive to multiplicative seasonality) moved the typical miss from ${mae_add:.1f} to ${_mu:.1f} billion "
    f"({_g:.0f}%), against ${_sn:.1f} billion for seasonal naive. Because nothing else changed, you can credit the whole difference to that one choice. "
    "statsmodels' Holt-Winters is close to, but not the same as, R's ets(), so the R numbers differ a little. With only 8 origins, treat a gain of a few percent as a tie.",
    "The MAEs are right but the gain is not. The gain compares the new model with the old one: 100 * (1 - mae_mul / mae_add)." if _mae_ok else
    "A number is off. Check: the benchmark is cv_mae(snaive); the multiplicative model uses \"mul\"; the gain divides by mae_add; nothing else was changed.")
