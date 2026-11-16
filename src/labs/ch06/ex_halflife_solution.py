from statsmodels.tsa.arima.model import ARIMA            # statsmodels' ARIMA estimator
s = fred("UMCSENT", start="1990-01-01", end="2019-12-01")  # consumer sentiment index (1966:Q1 = 100), monthly

# 1. Fit an AR(1) with a mean: (s_t - mean) = phi * (s_{t-1} - mean) + shock
fit = ARIMA(s, order=(1, 0, 0), trend="c").fit()          # p = 1: one lag; trend="c" = estimate a long-run mean
phi = float(fit.params["ar.L1"])                          # persistence: share of a gap that survives one month
print(round(phi, 4))

# 2. Half-life: months until half of a shock has faded
half_life = np.log(0.5) / np.log(phi)                     # solves phi^h = 0.5 for h
print(round(half_life, 2))

# 3. Scenario: a shock leaves sentiment 10 points below its average
gap12 = 10 * phi ** 12                                    # expected gap after 12 months, in index points
print(round(gap12, 2))
