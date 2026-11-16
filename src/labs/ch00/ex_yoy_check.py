# Hidden check for ex_yoy: recompute both growth rates.
_mom = 100 * (retail["2025-12-01"] / retail["2025-11-01"] - 1)
_yoy = 100 * (retail["2025-12-01"] / retail["2024-12-01"] - 1)
_ok = False
try:
    _ok = abs(float(mom) - _mom) < 1e-8 and abs(float(yoy) - _yoy) < 1e-8
except Exception:
    pass
check_that(_ok,
    f"Sales rose {_mom:.1f}% from November to December, but only {_yoy:.1f}% from December 2024 to December 2025. "
    "The big jump is mostly the holiday season, which happens every year. Comparing a month with the same month a year earlier cancels "
    "the seasonal pattern, which is why news reports on unadjusted data often quote year-over-year growth. Chapter 1 shows more ways to transform a series.",
    "Both changes start from December 2025 (dec25). Month over month divides by the month before (nov25); year over year divides by the same month a year earlier (dec24).")
