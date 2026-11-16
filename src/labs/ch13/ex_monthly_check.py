# Hidden grader: recomputes the monthly average (flow) and the end-of-month value (stock).
_a = ic.resample("MS").mean(); _e = cc.resample("MS").last(); _s = ic.resample("MS").sum()
_ok1 = "ic_m" in globals() and len(ic_m) == len(_a) and np.allclose(np.asarray(ic_m, float), _a.values)
_ok2 = "cc_m" in globals() and len(cc_m) == len(_e) and np.allclose(np.asarray(cc_m, float), _e.values)
_g = lambda s, m: float(s.loc[m].iloc[0]) / 1000
check_that(_ok1 and _ok2,
    f"Right. October 2026 averaged {_g(_a, '2026-10'):.1f}k initial claims a week, down from {_g(_a, '2026-09'):.1f}k in September. "
    f"The monthly sum says the opposite: {_g(_s, '2026-10'):.0f}k vs {_g(_s, '2026-09'):.0f}k, up {100 * (_g(_s, '2026-10') / _g(_s, '2026-09') - 1):.0f}%, "
    f"only because October has five week-ending Saturdays and September has four. Continuing claims at the end of October: {_e.iloc[-1] / 1000:,.0f}k people on benefits.",
    "Initial claims are a flow: summarize each month by its average week (.mean())." if not _ok1 else
    "Continuing claims are a stock: keep the final week of each month (.last()).")
