library(forecast)
# Total retail & food services = motor vehicles & parts + everything else ($ millions, SA)
parts <- list(Motor_vehicles = fred("RSMVPD", start = 2015), Ex_autos = fred("RSFSXMV", start = 2015))
total <- fred("RSAFS", start = 2015)
train <- lapply(parts, window, end = c(2025, 9))
test_total <- window(total, start = c(2025, 10))      # the 12 months we hide

# 1. Forecast each part 12 months ahead with ets() and keep the point forecasts
fc_parts <- sapply(train, function(s) forecast(ets(s, model = "ZZN"), h = 12)$mean)

# 2. Bottom-up: add the two parts month by month to get a total forecast
bu_total <- rowSums(fc_parts)

# Compare with forecasting the total directly
direct <- forecast(ets(window(total, end = c(2025, 9)), model = "ZZN"), h = 12)$mean
c(bottom_up_MAE = mean(abs(test_total - bu_total)), direct_MAE = mean(abs(test_total - direct)))
