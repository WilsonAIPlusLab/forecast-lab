import statsmodels.api as _sm
_dj = fred("PAYEMS").diff(); _dcl = 100 * np.log(fred("ICSA", to="month")).diff()
_D = pd.DataFrame({"dj": _dj, "dj_1": _dj.shift(1), "dcl_0": _dcl, "dcl_1": _dcl.shift(1)})["1990-01":"2019-12"]
_b = _sm.OLS(_D["dj"], _sm.add_constant(_D[["dj_1", "dcl_0", "dcl_1"]])).fit().params
_imp = _b["dcl_0"]; _lr = (_b["dcl_0"] + _b["dcl_1"]) / (1 - _b["dj_1"])
_ok_imp = "impact" in globals() and abs(float(impact) - _imp) < 1e-6
_ok_lr = "long_run" in globals() and abs(float(long_run) - _lr) < 1e-6
check_that(_ok_imp and _ok_lr,
  f"Impact = {_imp:.1f} and long run = {_lr:.1f} thousand jobs per 1% rise in claims. So a 10% jump in claims that persists costs about {round(-10 * _lr * 1000, -3):,.0f} jobs in total, roughly {_lr / _imp:.1f} times the first month's effect. That ratio is 1/(1 − φ) magnified by the lagged claims term: the more persistent job growth is, the further a shock echoes.",
  "Check the impact multiplier: it is the coefficient on same-month claims growth, b['dcl_0']." if not _ok_imp
  else "The impact is right. For the long run, add BOTH claims coefficients, b['dcl_0'] + b['dcl_1'], in parentheses before dividing.")
