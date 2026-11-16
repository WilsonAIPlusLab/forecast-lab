# Hidden check for ex_yoy: the answer must be the December 2025 YoY change of NSA retail sales.
_r = fred("RSXFSN", quiet=True)
_t = float((100 * (_r / _r.shift(12) - 1)).loc["2025-12-01"])
_m = float((100 * (_r / _r.shift(1) - 1)).loc["2025-12-01"])
_m24 = float((100 * (_r / _r.shift(1) - 1)).loc["2024-12-01"])
_sa = fred("RSAFS", quiet=True)
_s = float((100 * (_sa / _sa.shift(1) - 1)).loc["2025-12-01"])
try:
    _a = float(answer)
except Exception:
    _a = float("nan")
_fail = (f"That is the month-over-month change ({_m:.1f}%). For data that are not seasonally adjusted it mostly measures the holiday "
         "calendar: December beats November every year. Report the change from December 2024 instead." if abs(_a - _m) < 1e-6 else
         "Your YoY number is negative and large: shift(-12) pulls values from the future. Use shift(12)." if _a < -5 else
         'Fill the three blanks: shift(12), the label "2025-12-01", and answer = dec_yoy.')
check_that(abs(_a - _t) < 1e-6,
    f"December 2025 sales were {_t:.1f}% above December 2024, a solid but ordinary year. The {_m:.1f}% jump from November is the "
    f"usual holiday spike (December 2024 jumped {_m24:.1f}% too). Cross-check with the seasonally adjusted series (RSAFS, which also "
    f"includes restaurants): it rose just {_s:.1f}% from November. Hiring for a 12% boom would have been a mistake.",
    _fail)
