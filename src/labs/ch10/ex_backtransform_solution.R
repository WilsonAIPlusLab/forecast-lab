library(forecast)                                         # ets() and forecast()
oil <- fred("DCOILWTICO", start = 2015, to = "month")     # WTI crude oil, $ per barrel, monthly average of daily prices
oil <- window(oil, end = c(2026, 10))                     # drop November 2026: only part of that month is in
fit <- ets(log(oil))                                      # model the LOG price, so shocks are % moves
fc  <- forecast(fit, h = 12, level = 80)                  # 12 months ahead with an 80% interval, all in log units
mu  <- unname(fc$mean[12])                                     # log-scale point forecast for October 2027
lo  <- unname(fc$lower[12, 1])                                 # log-scale lower 80% limit
hi  <- unname(fc$upper[12, 1])                                 # log-scale upper 80% limit
sigma <- (hi - lo) / (2 * qnorm(0.9))                     # log-scale forecast spread implied by the band (z = 1.28)

# 1. Back to dollars: exp() undoes log(). This point is the MEDIAN price.
median_price <- exp(mu)
# 2. The 80% band in dollars: exp() each endpoint (no adjustment needed)
band <- exp(c(lo, hi))
# 3. The MEAN price (what budgets add up): the median times a bias adjustment
mean_price <- median_price * exp(sigma^2 / 2)

round(c(median = median_price, low = band[1], high = band[2], mean = mean_price), 2)   # $ per barrel
round(c(room_below = median_price - band[1], room_above = band[2] - median_price), 2)  # the band is lopsided
