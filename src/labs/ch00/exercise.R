library(forecast)                             # Hyndman's forecasting package

# 1. Load NSA housing starts from 2010 onward (ID: "HOUSTNSA")
starts <- fred(______, start = 2010)          # blank: the series ID, as text in quotes

# 2. Let auto.arima choose a model
fit_h <- auto.arima(starts)                   # searches many ARIMA models, keeps the best by AICc

# 3. Forecast 18 months ahead and draw the fan chart
fc_h <- forecast(fit_h, h = ______)           # blank: how many months ahead to forecast (a number)
viz_forecast(fc_h, from = 2018, title = "Housing starts: 18-month forecast")   # history from 2018, then the forecast fan
