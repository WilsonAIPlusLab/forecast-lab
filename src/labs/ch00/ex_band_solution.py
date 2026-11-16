from statsmodels.tsa.statespace.sarimax import SARIMAX   # seasonal ARIMA model class

# 1. Same data and model as the first lab's Python tab
retail = fred("RSXFSN", start=2012)           # monthly retail sales, $ millions, not seasonally adjusted
fit = SARIMAX(np.log(retail), order=(1, 1, 1), seasonal_order=(0, 1, 1, 12)).fit(disp=False)   # model on log sales
pred = fit.get_forecast(24)                   # 24 months ahead (still in logs)
mean = np.exp(pred.predicted_mean)            # point forecasts, back in $ millions
ci80 = np.exp(pred.conf_int(alpha=0.20))      # 80% band (lower, upper columns), back in $ millions

# 2. Find the next December among the 24 forecast months
k = np.where(mean.index.month == 12)[0][0]    # position of the first December (np.where finds matches)

# 3. Read the forecast for that month, converted to $ billions
point_bn = mean.iloc[k] / 1000                # $ millions -> $ billions
low80_bn = ci80.iloc[k, 0] / 1000             # column 0 = bottom of the 80% band, $ billions
high80_bn = ci80.iloc[k, 1] / 1000            # column 1 = top of the 80% band, $ billions

# 4. Say it in one plain sentence
print(f"December forecast: about ${point_bn:,.0f} billion; 80% band ${low80_bn:,.0f} to ${high80_bn:,.0f} billion.")
