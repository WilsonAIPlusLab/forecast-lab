library(forecast)                             # Hyndman's forecasting package

# 1. Same data and model as the first lab
retail <- fred("RSXFSN", start = 2012)        # monthly retail sales, $ millions, not seasonally adjusted
fit <- auto.arima(retail, lambda = 0)         # seasonal ARIMA on log sales; forecasts come back in $
fc <- forecast(fit, h = 24)                   # 24 months ahead, with 80% and 95% intervals

# 2. Find the next December among the 24 forecast months
k <- which(cycle(fc$mean) == 12)[1]           # cycle() gives the month number; [1] = the first December

# 3. Read the forecast for that month, converted to $ billions
point_bn <- fc$mean[k] / ______               # blank: how many millions make a billion?
low80_bn <- fc$lower[k, "80%"] / 1000         # bottom of the 80% band, $ billions
high80_bn <- fc$______[k, "80%"] / 1000       # blank: the matching top of the 80% band

# 4. Say it in one plain sentence
cat(sprintf("December forecast: about $%.0f billion; 80%% band $%.0f to $%.0f billion.\n",
            point_bn, low80_bn, high80_bn))
