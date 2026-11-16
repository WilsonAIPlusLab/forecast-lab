# Hidden check for ex_mase: recompute both MASEs independently.
def _m(y):
    tr, te = y[:"2022-12"], y["2023-01":]
    fc = np.array([tr.iloc[-12 + (i % 12)] for i in range(len(te))])
    return np.mean(np.abs(te.values - fc)) / np.nanmean(np.abs(tr.values[12:] - tr.values[:-12]))
_t = [_m(fred("RSXFSN", start=2010)), _m(fred("HOUSTNSA", start=2010))]
_ok = False
try:
    _ok = abs(float(result["retail"]) - _t[0]) < 1e-6 and abs(float(result["houses"]) - _t[1]) < 1e-6
except Exception:
    pass
check_that(_ok,
    f"MASE: retail {_t[0]:.2f}, housing starts {_t[1]:.2f}. The MAEs (about 24,800 $ millions vs 18 thousand homes) cannot be compared, but MASE can: the retail forecast missed only about 4% more than its benchmark's typical in-sample miss, while the housing forecast missed about 67% more. R's accuracy() gives exactly the same numbers.",
    "Seasonal naive compares each month with the same month a year earlier, so the shift is 12 for monthly data. Then divide the test-set MAE by scale.")
