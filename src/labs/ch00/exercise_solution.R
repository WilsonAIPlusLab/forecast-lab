library(forecast)

# 1. Load NSA housing starts from 2010 onward (ID: "HOUSTNSA")
starts <- fred("HOUSTNSA", start = 2010)

# 2. Let auto.arima choose a model
fit_h <- auto.arima(starts)

# 3. Forecast 18 months ahead and draw the fan chart
fc_h <- forecast(fit_h, h = 18)
viz_forecast(fc_h, from = 2018, title = "Housing starts: 18-month forecast")
