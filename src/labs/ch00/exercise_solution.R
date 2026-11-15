library(forecast)                             # Hyndman's forecasting package

# 1. Load NSA housing starts from 2010 onward (ID: "HOUSTNSA")
starts <- fred("HOUSTNSA", start = 2010)      # monthly housing starts (thousands of units), not seasonally adjusted

# 2. Let auto.arima choose a model
fit_h <- auto.arima(starts)                   # searches many ARIMA models, keeps the best by AICc

# 3. Forecast 18 months ahead and draw the fan chart
fc_h <- forecast(fit_h, h = 18)               # forecast 18 months ahead, with 80% and 95% intervals
viz_forecast(fc_h, from = 2018, title = "Housing starts: 18-month forecast")   # history from 2018, then the forecast fan
