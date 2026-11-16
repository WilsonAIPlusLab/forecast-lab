# Hidden check for ex_cumulative: recompute the multipliers from the same ADL(1,1).
import statsmodels.api as _sm
_dj = fred("PAYEMS").diff(); _dcl = 100 * np.log(fred("ICSA", to="month")).diff()
_D = pd.DataFrame({"dj": _dj, "dj_1": _dj.shift(1), "dcl_0": _dcl, "dcl_1": _dcl.shift(1)})["1990-01":"2019-12"]
_b = _sm.OLS(_D["dj"], _sm.add_constant(_D[["dj_1", "dcl_0", "dcl_1"]])).fit().params
_m0 = _b["dcl_0"]; _m1 = _b["dcl_1"] + _b["dj_1"] * _m0; _m2 = _b["dj_1"] * _m1; _c3 = 10 * (_m0 + _m1 + _m2)
def _close(name, v):
    try: return abs(float(globals()[name]) - v) < 1e-6
    except Exception: return False
_ok1 = _close("m1", _m1); _ok2 = _close("m2", _m2)
_f = lambda v: f"{round(v * 1000, -3):,.0f}"
check_that(_ok1 and _ok2,
  f"Right. A lasting 10% jump in claims goes with about {_f(-10 * _m0)} fewer jobs added this month, {_f(-10 * _m1)} fewer next month and {_f(-10 * _m2)} fewer the month after: about {_f(-_c3)} fewer jobs in total after three months. That total is the cumulative effect, {_c3 / (10 * _m0):.1f} times the impact. When you report a number, say which one it is.",
  "Month 1 has two parts: the lagged claims coefficient b1, plus phi times the month-0 response m0." if not _ok1
  else "Month 1 is right. In month 2 there is no claims coefficient left (the model stops at lag 1), so only the echo phi * m1 remains.")
