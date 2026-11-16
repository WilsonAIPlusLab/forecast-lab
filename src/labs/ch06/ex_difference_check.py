# Hidden check for ex_difference.
from statsmodels.tsa.stattools import kpss as _kpss, adfuller as _adf, acf as _acf
_y = fred("GS10", start="1990-01-01", quiet=True)
_pk = _kpss(_y, regression="c", nlags=int(4 * (len(_y) / 100) ** 0.25))[1]
_dy = _y.diff().dropna()
_r1 = _acf(_dy, nlags=1)[1]
_ok = False
try:
    _ok = abs(float(p_kpss) - _pk) < 1e-8 and len(dy) == len(_dy) and np.allclose(np.asarray(dy, dtype=float), _dy.to_numpy()) and float(d) == 1
except Exception:
    pass
check_that(_ok,
  f"Right: d = 1. Here is the defense you would write: \"In levels, ADF cannot reject a unit root (p = {p_adf:.2f}) and KPSS rejects stationarity (p = {_pk:.2f}), so both tests say the yield wanders. Its monthly change passes both tests (ADF p = {p_adf_d:.3f}, KPSS p = {p_kpss_d:.2f}), so one difference is enough.\" One more check: the change has a lag-1 autocorrelation of {_r1:.2f}, far from the -0.5 that would warn of over-differencing. Interest rates cannot trend forever, but since 1990 the 10-year yield fell from about 8% to under 1% and climbed back above 5%, which behaves like a unit root over any forecasting horizon.",
  "Check three things. The test with the null 'stationary' is kpss(). The first difference is y.diff(). And d: in levels both tests point to a unit root, while the change looks stationary, so how many differences do you need?")
