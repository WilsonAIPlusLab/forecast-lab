import warnings
from statsmodels.tsa.stattools import adfuller, kpss     # the two unit-root tests
warnings.simplefilter("ignore")                           # hide "p-value outside the look-up table" notes
y = fred("GS10", start="1990-01-01")                      # 10-year Treasury yield, % (monthly average)
k_adf = lambda x: int((len(x) - 1) ** (1 / 3))            # ADF lag count, as in R's adf.test()
k_kpss = lambda x: int(4 * (len(x) / 100) ** 0.25)        # KPSS lag count, as in R's kpss.test()

# 1. Test the level. ADF null: unit root. KPSS null: stationary. [1] picks the p-value.
p_adf = adfuller(y, maxlag=k_adf(y), regression="ct", autolag=None)[1]   # small p = evidence of stationarity
# Blank: the test whose null hypothesis is "stationary"
p_kpss = ______(y, regression="c", nlags=k_kpss(y))[1]    # small p = evidence of a unit root

# 2. Test the month-to-month change in the yield
# Blank: the pandas method that takes first differences
dy = y.______().dropna()                                  # change in the yield, percentage points
p_adf_d = adfuller(dy, maxlag=k_adf(dy), regression="ct", autolag=None)[1]
p_kpss_d = kpss(dy, regression="c", nlags=k_kpss(dy))[1]
print({k: round(float(v), 3) for k, v in dict(level_ADF=p_adf, level_KPSS=p_kpss, change_ADF=p_adf_d, change_KPSS=p_kpss_d).items()})

# 3. Your decision: how many differences should the model use, 0 or 1?
# Blank: a number, based on the four p-values above
d = ______
