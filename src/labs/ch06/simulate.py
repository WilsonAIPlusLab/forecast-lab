#| **Simulate four "laboratory" series** of 300 months each. NumPy's random generator differs from R's, so the draws (and the exact p-values) differ from the R tab. The verdicts are the same.
#| - **White noise**: independent shocks.
#| - **AR(1), φ = 0.7**: today keeps 70% of yesterday.
#| - **Random walk**: a running sum of shocks (`cumsum`).
#| - **Random walk with drift**: the same, plus 0.2 every month.
import warnings
rng = np.random.default_rng(2026)
n = 300
e = rng.standard_normal((4, n))
ar = np.zeros(n)
for t in range(1, n):
    ar[t] = 0.7 * ar[t - 1] + e[1, t]
idx = pd.date_range("2001-01-01", periods=n, freq="MS")
sims = {
    "White noise": pd.Series(e[0], idx),
    "AR(1), phi = 0.7": pd.Series(ar, idx),
    "Random walk": pd.Series(np.cumsum(e[2]), idx),
    "RW with drift": pd.Series(np.cumsum(0.2 + e[3]), idx),
}

#| **Look first.** The top two hug a fixed level; the bottom two wander off.
viz_ts(**sims, facet=True, title="Two series return to a fixed level; two wander off")

#| **ADF and KPSS, set up exactly like R's `tseries` defaults**: ADF with a constant and trend and $\lfloor (n-1)^{1/3} \rfloor$ lags; KPSS around a level with $\lfloor 4 (n/100)^{1/4} \rfloor$ lags. Opposite nulls: ADF's null is a unit root, KPSS's null is stationarity.
from statsmodels.tsa.stattools import adfuller, kpss

def adf_p(x):
    return adfuller(x, maxlag=int((len(x) - 1) ** (1 / 3)), regression="ct", autolag=None)[1]

def kpss_p(x):
    with warnings.catch_warnings():          # silence the "outside the look-up table" note
        warnings.simplefilter("ignore")
        return kpss(x, regression="c", nlags=int(4 * (len(x) / 100) ** 0.25))[1]

def ndiffs(x, max_d=2):
    """Like R's forecast::ndiffs(): difference until KPSS stops rejecting at 5%."""
    x = pd.Series(x).dropna()
    for d in range(max_d + 1):
        if kpss_p(x) > 0.05:
            return d
        x = x.diff().dropna()
    return max_d

#| **The verdict table.** ADF rejects and KPSS doesn't → stationary. The reverse → unit root. statsmodels reports exact ADF p-values (R caps them at 0.01), but KPSS is still capped between 0.01 and 0.10.
tests = pd.DataFrame({k: {"ADF p (H0: unit root)": adf_p(v), "KPSS p (H0: stationary)": kpss_p(v), "ndiffs()": ndiffs(v)}
                      for k, v in sims.items()}).T
print(tests.round(3))
viz_table(tests, digits=3, title="Tests agree: white noise and AR(1) are stationary, both random walks need one difference")

#| **Difference the random walk once** and test again: one difference gives back the white-noise shocks.
rw_diff = sims["Random walk"].diff().dropna()
print({"ADF": round(float(adf_p(rw_diff)), 4), "KPSS": round(float(kpss_p(rw_diff)), 3), "ndiffs": ndiffs(rw_diff)})
