# Hidden check for ex_backtransform: compares the three back-transformed numbers with the right answers.
_med = np.exp(mu); _band = np.exp([lo, hi]); _mean = _med * np.exp(sigma**2 / 2)
_ok = "median_price" in dir() and "band" in dir() and "mean_price" in dir() and len(band) == 2 and \
    abs(median_price - _med) < 1e-6 and np.all(np.abs(np.asarray(band) - _band) < 1e-6) and abs(mean_price - _mean) < 1e-6
check_that(_ok,
    f"Median ${_med:.2f}, 80% band ${_band[0]:.2f} to ${_band[1]:.2f}, mean ${_mean:.2f} per barrel. The band reaches ${_med - _band[0]:.2f} below the median "
    f"but ${_band[1] - _med:.2f} above it: in dollars, a log model's band is lopsided because prices can rise more than 100% but cannot fall below zero. "
    f"The mean sits {100 * (_mean / _med - 1):.1f}% above the median, so a fuel budget that adds up across months should use the mean.",
    "Check the three blanks. np.exp() undoes np.log(), for the point and for each band endpoint (the lower one is stored in lo). The mean needs the extra factor np.exp(sigma**2 / 2): square the log-scale spread, then halve it.")
