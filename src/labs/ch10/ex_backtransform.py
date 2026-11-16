import warnings; warnings.filterwarnings("ignore")        # hide statsmodels fitting warnings
from statsmodels.tsa.exponential_smoothing.ets import ETSModel   # exponential smoothing (ETS)
from scipy.stats import norm                              # normal distribution: norm.ppf gives z-values
oil = fred("DCOILWTICO", start="2015-01-01", end="2026-10-31", to="month")   # WTI crude, $/barrel, monthly average; Nov 2026 is partial, so stop at Oct
# ETS(A,N,N) on the LOG price, the model R's ets() picks; shocks are % moves
fit = ETSModel(np.log(oil), error="add").fit(disp=False)
n = len(oil)                                              # number of observed months
# 12 months ahead with an 80% interval (alpha=0.2 leaves 20% outside), all in log units
fc = fit.get_prediction(start=n, end=n + 11).summary_frame(alpha=0.2)
mu = fc["mean"].iloc[-1]                                  # log-scale point forecast for October 2027
lo = fc["pi_lower"].iloc[-1]                              # log-scale lower 80% limit
hi = fc["pi_upper"].iloc[-1]                              # log-scale upper 80% limit
sigma = (hi - lo) / (2 * norm.ppf(0.9))                   # log-scale forecast spread implied by the band (z = 1.28)

# 1. Back to dollars: undo the log. This point is the MEDIAN price.
# blank: the numpy function that undoes a natural log
median_price = ______(mu)
# 2. The 80% band in dollars: transform each endpoint (no adjustment needed)
# blank: the log-scale lower limit you stored above
band = np.exp([______, hi])
# 3. The MEAN price (what budgets add up): the median times a bias adjustment
# blank: the log-scale variance (the spread squared)
mean_price = median_price * np.exp(______ / 2)

print("median, low, high, mean ($/barrel):", np.round([median_price, band[0], band[1], mean_price], 2))
print("room below, room above:", np.round([median_price - band[0], band[1] - median_price], 2))   # the band is lopsided
