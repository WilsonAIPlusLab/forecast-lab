from statsmodels.tsa.arima.model import ARIMA            # statsmodels' ARIMA estimator
pce = fred("PCEPILFE", start="2000-01-01")                # core PCE price index (2017 = 100), through Sept 2026
g = (100 * np.log(pce).diff()).dropna()                   # monthly inflation: log difference x 100, % per month

# A model of the log differences: ARMA(1,1) with a mean (inflation drifts back to its average)
fit = ARIMA(g, order=(1, 0, 1), trend="c").fit()
fc = fit.forecast(12).to_numpy()                          # 12 monthly log changes, % (Oct 2026 to Sept 2027)
last = float(pce.iloc[-1])                                # latest observed index level (Sept 2026)

# 1. Cumulative log change from Sept 2026 to each future month (divide by 100 to undo the x 100)
# Blank: the NumPy function that keeps a running total
cum = np.______(fc) / 100

# 2. Back to the index: undo the log
# Blank: the NumPy inverse of np.log()
level = last * np.______(cum)                             # forecast index level for each future month
print(round(level[11], 2))                                # September 2027 ([11] = 12th month, counting from 0)

# 3. Implied 12-month inflation for September 2027, in %
# Blank: the latest observed index level (a variable defined above)
infl_12 = 100 * (level[11] / ______ - 1)
print(round(infl_12, 2))
