library(forecast)                                     # ets() and forecast()
# Total retail & food services = motor vehicles & parts + everything else ($ millions, SA); the parts go in a list
parts <- list(Motor_vehicles = fred("RSMVPD", start = 2015), Ex_autos = fred("RSFSXMV", start = 2015))
total <- fred("RSAFS", start = 2015)                  # the published total, to compare against
train <- lapply(parts, window, end = c(2025, 9))      # lapply runs window() on each part: data through Sep 2025
test_total <- window(total, start = c(2025, 10))      # the 12 months we hide

# 1. Forecast each part 12 months ahead with ets() and keep the point forecasts
fc_parts <- sapply(train, function(s) forecast(ets(s, model = "ZZN"), h = 12)$mean)   # $mean = point forecasts
# sapply returns a 12 x 2 matrix: one row per month, one column per part

# 2. Bottom-up: add the two parts month by month to get a total forecast
bu_total <- rowSums(fc_parts)                         # rowSums adds across each row: motor vehicles + ex-autos

# Compare with forecasting the total directly
# same ETS method on the total itself; "ZZN" = R picks error and trend type, no seasonality (data are SA)
direct <- forecast(ets(window(total, end = c(2025, 9)), model = "ZZN"), h = 12)$mean
# mean absolute error of each approach over the 12 hidden months ($ millions; lower is better)
c(bottom_up_MAE = mean(abs(test_total - bu_total)), direct_MAE = mean(abs(test_total - direct)))
