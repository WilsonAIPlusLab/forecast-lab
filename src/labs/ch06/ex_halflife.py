from statsmodels.tsa.arima.model import ARIMA            # statsmodels' ARIMA estimator
s = fred("UMCSENT", start="1990-01-01", end="2019-12-01")  # consumer sentiment index (1966:Q1 = 100), monthly

# 1. Fit an AR(1) with a mean: (s_t - mean) = phi * (s_{t-1} - mean) + shock
# Blank: the AR order p for an AR(1)
fit = ARIMA(s, order=(______, 0, 0), trend="c").fit()     # trend="c" = estimate a long-run mean
phi = float(fit.params["ar.L1"])                          # persistence: share of a gap that survives one month
print(round(phi, 4))

# 2. Half-life: months until half of a shock has faded, log(0.5) / log(phi)
# Blank: the share of the shock that is left at the half-life
half_life = np.log(______) / np.log(phi)
print(round(half_life, 2))

# 3. Scenario: a shock leaves sentiment 10 points below its average.
#    Expected gap 12 months later = 10 * phi^12   (** is "to the power of" in Python)
# Blank: the number of months
gap12 = 10 * phi ** ______
print(round(gap12, 2))
