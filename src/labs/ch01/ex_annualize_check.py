# Hidden check for ex_annualize: annualized quarterly growth matches BEA's published rate; log change is close to % change.
_g = fred("GDPC1", quiet=True); _b = float(fred("A191RL1Q225SBEA", quiet=True).iloc[-1])
_r = _g.iloc[-1] / _g.iloc[-2]
_gq, _ga, _gl = 100 * (_r - 1), 100 * (_r ** 4 - 1), 100 * np.log(_r)
_ok_a = "g_ann" in globals() and abs(float(g_ann) - _ga) < 1e-8
_ok_l = "g_log" in globals() and abs(float(g_log) - _gl) < 1e-8
_fail = ("You multiplied by 4. Annualizing compounds: raise the growth factor to the 4th power." if "g_ann" in globals() and abs(float(g_ann) - 4 * _gq) < 1e-6 else
         "Blank 1: a year has 4 quarters, so raise q2/q1 to the power 4." if not _ok_a else
         "Blank 2: the log change is np.log(q2) - np.log(q1).")
check_that(_ok_a and _ok_l,
    f"Both numbers are right. GDP grew {_gq:.2f}% from the previous quarter, which compounds to {_ga:.2f}% at an annual rate; BEA rounds that to "
    f"{_b:.1f}%. The log change, {_gl:.2f}, is within {abs(_gq - _gl):.3f} of the percent change, as it should be for a small move. To go back "
    f"from an annual rate to a quarterly one, take the 4th root: 100 x ({1 + _b / 100:.3f}^(1/4) - 1) = {100 * ((1 + _b / 100) ** 0.25 - 1):.2f}%. "
    f"Over the past four quarters GDP grew {100 * (_g.iloc[-1] / _g.iloc[-5] - 1):.1f}%: that is the year-over-year view.",
    _fail)
