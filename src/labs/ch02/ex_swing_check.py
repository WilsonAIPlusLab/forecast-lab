# Hidden check for ex_swing: recompute the December gaps and compare.
_d = seasonal_decompose(ecom, model="additive", period=12)
_p = (100 * (ecom / _d.trend - 1))[ecom.index.month == 12]
_u = (ecom - _d.trend)[ecom.index.month == 12]
_ok1 = _ok2 = False
try:
    _ok1 = bool(np.allclose(gap_pct.values, (100 * (ecom / _d.trend - 1)).values, equal_nan=True))
    _ok2 = bool(np.array_equal(np.asarray(is_dec), np.asarray(ecom.index.month == 12)))
except Exception:
    pass
_ok3 = ("multiplicative" in dir()) and multiplicative is True
check_that(_ok1 and _ok2 and _ok3,
    f"December's boost grew from ${_u.iloc[0] / 1000:.1f}bn (2000) to ${_u.iloc[17] / 1000:.1f}bn (2017) as the business grew, but in percent it stayed in the same range ({_p.iloc[0]:+.0f}% vs {_p.iloc[17]:+.0f}%). Single years wobble (2018 is low), so judge the overall pattern, not one row. That is multiplicative seasonality: model log(sales), and every seasonal effect becomes a constant percentage.",
    "Step 1: percent above trend is 100 * (data / trend - 1), and the trend is stored in `dec.trend`." if not _ok1 else
    "Step 2: December is month number 12, so `is_dec = ecom.index.month == 12`." if not _ok2 else
    "Step 3: look at the table. The dollar column grows a lot; the percent column does not. Which kind of seasonality is that? Answer True or False (no quotes).")
