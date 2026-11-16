# Hidden check for ex_halflife.
from statsmodels.tsa.arima.model import ARIMA as _ARIMA
_f = _ARIMA(fred("UMCSENT", start="1990-01-01", end="2019-12-01", quiet=True), order=(1, 0, 0), trend="c").fit()
_phi = float(_f.params["ar.L1"]); _hl = np.log(0.5) / np.log(_phi)
_ok = False
try:
    _ok = abs(float(half_life) - _hl) < 1e-6 and abs(float(gap12) - 10 * _phi ** 12) < 1e-6
except Exception:
    pass
check_that(_ok,
  f"Right. phi = {_phi:.3f}: each month, {100 * _phi:.1f}% of any gap from the long-run mean ({float(_f.params['const']):.1f}) survives. Half of a shock is gone after {_hl:.1f} months, and a 10-point drop is still {10 * _phi ** 12:.1f} points a year later. In words for your manager: \"sentiment shocks are persistent but not permanent; expect about half of a drop to be undone within a year.\" Note that ADF cannot reject a unit root for this series: with phi this close to 1 the test has little power, and an index that stayed between about 55 and 112 over these 30 years cannot wander forever.",
  "Three blanks: the AR order is 1; the half-life puts np.log(0.5) on top, because half of the shock is left; and the gap after a year uses phi to the power 12.")
