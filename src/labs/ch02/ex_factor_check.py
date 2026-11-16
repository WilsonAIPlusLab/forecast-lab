# Hidden check for ex_factor: recompute the factor and the December 2025 percentage.
_f = nsa / sa
_p = 100 * (_f["2025-12-01"] - 1)
_ok1 = _ok2 = False
try:
    _ok1 = bool(np.allclose(factor.values, _f.values, equal_nan=True))
    _ok2 = abs(float(pct_above) - _p) < 1e-8
except Exception:
    pass
check_that(_ok1 and _ok2,
    f"December 2025 ran {_p:.1f}% above a typical month, so about $75bn of its sales were seasonal, not news. Say it as \"December is {_p:.0f}% above a typical month\", not as a growth rate. Bonus: look at the Februaries in `factor`. 2024 is {_f['2024-02-01']:.3f} but 2025 is {_f['2025-02-01']:.3f}: the leap day adds about 1/28 = 3.6% to February's sales, and the factor absorbs it.",
    "Step 1: the factor is raw / adjusted, so the raw series `nsa` goes on top." if not _ok1 else
    "Step 2: percent above typical = 100 * (factor - 1), using the December factor stored in `f_dec`.")
