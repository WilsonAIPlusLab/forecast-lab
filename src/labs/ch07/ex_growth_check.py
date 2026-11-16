# Hidden check for ex_growth: recompute the growth-rate correlations and compare.
_w = lambda s: s.loc["2010-01":"2019-12"]
_g = lambda s: 100 * np.log(s).diff()
_j = _w(fred("PAYEMS")); _c = _w(fred("ICSA", to="month")); _p = _w(fred("CPIAUCSL"))
_rg = [_g(_c).corr(_g(_j)), _g(_p).corr(_g(_j))]
_rl = [_c.corr(_j), _p.corr(_j)]
try:
    _v = [float(v) for v in list(r_growth)]
    _has = len(_v) == 2
except Exception:
    _v, _has = [], False
_ok = _has and all(abs(a - b) < 1e-6 for a, b in zip(_v, _rg))
_half = _has and abs(_v[0] - _rg[0]) < 1e-6
check_that(_ok,
  f"Right. In levels, claims ({_rl[0]:.2f}) and CPI ({_rl[1]:.2f}) both look like near-perfect partners for jobs, because all three trended steadily through the 2010s. In monthly growth rates, CPI drops to {_rg[1]:.2f} (no link) and claims to {_rg[0]:.2f}: a real but modest link. Your reply: 'The -0.97 measures two trends, not a relationship. In growth rates, claims account for only about {100 * _rg[0] ** 2:.0f}% of the month-to-month variation in job growth (r squared).'",
  "The claims number is right. For CPI, apply the same growth function g() to cpi." if _half
  else "Check g(): it should return 100 * np.log(x).diff(), the monthly % change. Levels or plain differences give different numbers.")
