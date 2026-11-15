#| **Load the data and split it in time.** U.S. e-commerce sales (electronic shopping and mail-order houses), in $ millions, **not seasonally adjusted**, so the holiday peak is still in the data. We train through August 2025 and hold out the 12 months after that as the test set.
library(forecast)
online <- fred("MRTSSM4541USN", start = 2015)
train  <- window(online, end = c(2025, 8))
test   <- window(online, start = c(2025, 9))

#| **Simple exponential smoothing (SES): level only.** `ses()` keeps one number, the *level*, and updates it after every month: new level = α × this month + (1 − α) × old level. We fix α = 0.3 so you can see what the parameter does. The forecast is **flat**: SES has no idea the series trends or has a December peak.
f_ses <- ses(train, h = 12, alpha = 0.3)
round(f_ses$mean[1:3])

#| **Holt's linear trend: level + slope.** `holt()` adds a second smoothed number, the *trend* (slope), updated with its own parameter β. The forecast is now a straight line that keeps rising. `damped = TRUE` adds a damping factor φ < 1 so the slope fades out over the horizon instead of continuing forever.
f_holt   <- holt(train, h = 12, alpha = 0.3, beta = 0.05)
f_damped <- holt(train, h = 12, alpha = 0.3, beta = 0.05, damped = TRUE, phi = 0.9)

#| **Holt-Winters: level + slope + season.** `hw()` adds 12 *seasonal indices*, one per month, updated with parameter γ. With `seasonal = "multiplicative"` an index is a percentage (an index of 1.26 for December means "26% above the level"), so the holiday peak grows as the business grows. Here we let `hw()` estimate α, β and γ itself.
f_hw <- hw(train, h = 12, seasonal = "multiplicative")
round(f_hw$model$par[c("alpha", "beta", "gamma")], 3)

#| **Plot all four against what actually happened.** Each component you add fixes one failure of the method before it: SES misses the growth, Holt misses the seasons, and only Holt-Winters follows the November–December peak.
viz_compare(history = window(train, start = 2021), actual = test,
            SES = f_ses, Holt = f_holt, `Damped Holt` = f_damped, `Holt-Winters (mult.)` = f_hw,
            title = "Only Holt-Winters follows the holiday peak")

#| **Score them on the test year.** MASE below 1 means the method's errors are smaller than the typical in-sample error of the seasonal naive benchmark from Chapter 3. Notice how far the methods without a seasonal component fall behind.
score <- function(f) accuracy(f, test)["Test set", c("ME", "MAE", "RMSE", "MAPE", "MASE")]
scores <- rbind(SES = score(f_ses), Holt = score(f_holt), `Damped Holt` = score(f_damped),
                `Holt-Winters (mult.)` = score(f_hw), `Seasonal naive` = score(snaive(train, h = 12)))
viz_table(scores, highlight = c("MAE", "RMSE", "MAPE", "MASE"), digits = 2,
          title = "Only the seasonal method beats seasonal naive")
