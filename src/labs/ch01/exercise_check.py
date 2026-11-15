_r = pd.read_csv("data/CPIAUCSL.csv")
_c = pd.Series(_r["CPIAUCSL"].values, index=pd.to_datetime(_r["observation_date"])).asfreq("MS")
_i = 100 * (_c / _c.shift(12) - 1)
_d = _i.last_valid_index()
_truth = float(_i[_d])
_f = fred("CPIAUCSL", quiet=True)
_fi = 100 * (_f / _f.shift(12) - 1)
_extra = (f" If you had loaded CPI with fred(), which fills October 2025 by interpolation, you would also get {_fi.iloc[-1]:.1f}% for "
          f"{_fi.index[-1]:%B %Y}, but that number divides by an estimated base month, not a published one. BLS itself does not "
          "publish 12-month changes for October 2026 for that reason.") if _fi.index[-1] != _d else ""
_ok = "latest" in globals() and np.isscalar(latest) and abs(float(latest) - _truth) < 1e-8
_neg = "latest" in globals() and np.isscalar(latest) and float(latest) < 0
check_that(_ok,
    f"CPI inflation was {_truth:.1f}% in {_d:%B %Y}, the latest month you can compute from published data. The next month is NaN "
    "because its year-ago value falls on October 2025, which BLS never published after the 2025 shutdown." + _extra +
    " (BLS headlines quote the not seasonally adjusted index, so its 12-month figures can differ slightly from this SA calculation.)",
    "Your inflation is negative: shift(-12) pulls values from the future. Use shift(12) to compare with a year earlier." if _neg else
    "Two blanks: shift(12) gives the value from 12 months earlier, and last_valid_index() returns the date of the last non-missing value.")
