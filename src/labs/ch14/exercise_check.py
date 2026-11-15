def _ff(x):
    return ExponentialSmoothing(x, trend="add", damped_trend=True, seasonal="mul", seasonal_periods=12).fit(use_brute=False).forecast(12)
_n = len(y); _o = range(_n - 48, _n - 3, 4)
_E = np.full((len(_o), 12), np.nan)
for _r, _k in enumerate(_o):
    _f = _ff(y.iloc[:_k]).values
    for _j in range(min(12, _n - _k)):
        _E[_r, _j] = y.iloc[_k + _j] - _f[_j]
_p = _ff(y).iloc[-1]
_lo, _hi, _m1 = _p + np.nanquantile(_E[:, 11], 0.10), _p + np.nanquantile(_E[:, 11], 0.90), np.nanmean(np.abs(_E[:, 0]))
try:
    _num_ok = bool(np.allclose([point, lo80, hi80, mae1], [_p, _lo, _hi, _m1], rtol=1e-6))
except Exception:
    _num_ok = False
_txt_ok = isinstance(globals().get("summary_text"), str) and all(f"{v:.1f}" in summary_text for v in (_p, _lo, _hi, _m1))
check_that(_num_ok and _txt_ok,
    f"Shipped. Your forecast is ${_p:.1f} billion, with an 80% range ${_hi - _lo:.1f} billion wide "
    f"(${_p - _lo:.1f} billion below, ${_hi - _p:.1f} billion above), built from errors the model made at origins it had never seen. "
    "statsmodels' Holt-Winters is close to, but not the same as, R's ETS(M,Ad,M), so expect slightly different numbers from the R version. "
    "Before sending, add one risk and one trigger, as in the Studio's summary.",
    "A number is off. Check: the class is ExponentialSmoothing; the 80% range uses column h - 1 (Python counts from 0, so that is the 12-month horizon); and nothing else was changed."
    if not _num_ok else "The numbers are right but the summary does not show them all. The last slot should be mae1, the typical one-month-ahead miss.")
