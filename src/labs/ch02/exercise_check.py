_f = STL(np.log(retail), period=12, seasonal=13, robust=True, seasonal_deg=0,
         seasonal_jump=2, trend_jump=3, low_pass_jump=2).fit(inner_iter=1, outer_iter=15)
_sa = np.exp(np.log(retail) - _f.seasonal)
_g = 100 * (_sa["2025-12-01"] / _sa["2025-11-01"] - 1)
_o = fred("RSAFS", quiet=True) - fred("RSFSDP", quiet=True)
_og = 100 * (_o["2025-12-01"] / _o["2025-11-01"] - 1)
_rg = 100 * (retail["2025-12-01"] / retail["2025-11-01"] - 1)
_ok = False
try:
    _ok = abs(float(growth) - _g) < 1e-6
except Exception:
    pass
check_that(_ok,
    f"Adjusted growth = {_g:.1f}%, against a raw jump of {_rg:.1f}%. Almost all of December's leap was just December. Census's official X-13 figure for the same month is {_og:+.1f}%: it also removes trading-day and holiday effects that STL ignores. Verdict: a solid, ordinary December, not a boom.",
    "Two checks: (1) seasonal adjustment subtracts the seasonal component, so the first blank is `seasonal`; (2) growth is new / old - 1, so divide by November's adjusted value, `sa[\"2025-11-01\"]`.")
