# Hidden check for ex_cost: recompute both costs, and the cost of seasonal naive with a 5% buffer.
def _c(fc):
    d = (test - fc).values
    return np.where(d > 0, 4 * d, -d).mean()
_t = [_c(f_sn), _c(f_nv)]; _b = _c(1.05 * f_sn)
_ok = False
try:
    _ok = abs(float(costs["Seasonal naive"]) - _t[0]) < 1e-6 and abs(float(costs["Naive"]) - _t[1]) < 1e-6
except Exception:
    pass
check_that(_ok,
    f"Cost: seasonal naive {_t[0]:,.0f}, naive {_t[1]:,.0f}. Under MAE seasonal naive wins easily, but under a 4-to-1 cost naive wins, only because it is too high in most months: it repeats December's peak all year. The better fix is to keep the good forecast and shade it up: seasonal naive plus a 5% buffer costs {_b:,.0f}. (Choose such a buffer on past data, not on the test set.)",
    "An under-forecast (e > 0) costs 4 per unit, so the first blank is 4. An over-forecast has e < 0, and its cost must be positive, so the second blank is -e.")
