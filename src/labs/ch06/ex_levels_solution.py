from statsmodels.tsa.arima.model import ARIMA            # statsmodels' ARIMA estimator
pce = fred("PCEPILFE", start="2000-01-01")                # core PCE price index (2017 = 100), through Sept 2026
g = (100 * np.log(pce).diff()).dropna()                   # monthly inflation: log difference x 100, % per month

# A model of the log differences: ARMA(1,1) with a mean (inflation drifts back to its average)
fit = ARIMA(g, order=(1, 0, 1), trend="c").fit()
fc = fit.forecast(12).to_numpy()                          # 12 monthly log changes, % (Oct 2026 to Sept 2027)
last = float(pce.iloc[-1])                                # latest observed index level (Sept 2026)

# 1. Cumulative log change from Sept 2026 to each future month (divide by 100 to undo the x 100)
cum = np.cumsum(fc) / 100                                 # undoes the difference: changes add up to a level change

# 2. Back to the index: undo the log
level = last * np.exp(cum)                                # np.exp() undoes the log
print(round(level[11], 2))                                # September 2027 ([11] = 12th month, counting from 0)

# 3. Implied 12-month inflation for September 2027, in %
infl_12 = 100 * (level[11] / last - 1)                    # compare with the latest observed level
print(round(infl_12, 2))
