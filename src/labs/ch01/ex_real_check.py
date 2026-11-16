# Hidden check for ex_real: real gas prices in October-2026 dollars and the month of the real record.
_g = fred("GASREGW", to="month", quiet=True); _c = fred("CPIAUCSL", quiet=True)
_rg = (_g * _c.loc["2026-10-01"] / _c).dropna()
_pk = _rg.idxmax()
try:
    _v = float(real_gas.loc["2008-06-01"])
except Exception:
    _v = float("nan")
_ok_series = abs(_v - float(_rg.loc["2008-06-01"])) < 1e-6
_fail = ("Your 2008 price got smaller, so you converted the wrong way: multiply by today's CPI (cpi_now) and divide by the CPI of the month itself."
         if _v < float(_g.loc["2008-06-01"]) else
         "Blank 1: to express a price in October-2026 dollars, multiply by the October 2026 CPI, cpi_now." if not _ok_series else
         "Blank 2: .idxmax() returns the date label of the largest value.")
_peak_ok = False
try:
    _peak_ok = pd.Timestamp(real_peak) == _pk
except Exception:
    pass
check_that(_ok_series and _peak_ok,
    f"Your manager is wrong twice. In sticker prices the record is ${_g.loc['2022-06-01']:.2f} in June 2022, above today's "
    f"${_g.loc['2026-10-01']:.2f}. In today's dollars the record is {_pk:%B %Y} at ${_rg.max():.2f} a gallon; June 2022's "
    f"${_g.loc['2022-06-01']:.2f} is worth ${_rg.loc['2022-06-01']:.2f} now. Always say which year's dollars you are quoting.",
    _fail)
