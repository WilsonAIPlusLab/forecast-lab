#| **Retail sales, not seasonally adjusted**, from 2012. We hold out January 2024 onward as a test set, exactly as in Chapter 3. `tslm()` from **forecast** is `lm()` for time series: it knows the dates, so it can build trend and seasonal terms for you.
library(forecast)
retail <- window(fred("RSXFSN"), start = c(2012, 1))   # $ millions, NSA
train  <- window(retail, end = c(2023, 12))
test   <- window(retail, start = c(2024, 1))

#| **An event dummy for April 2020**, the month stores closed. Start with a series of zeros shaped like the training data, then set one month to 1. A dummy that is 1 for a single month is called a *pulse* dummy: it lets that month be an outlier without dragging the trend and seasonal estimates toward it.
covid <- train * 0
window(covid, start = c(2020, 4), end = c(2020, 4)) <- 1

#| **Trend + 11 monthly dummies + the pulse.** `season` creates dummies for February through December; January is the baseline absorbed by the intercept. `lambda = 0` fits the model to log sales, so each seasonal coefficient is (approximately) a percentage gap from January, and `forecast()` converts back to dollars for us.
fit <- tslm(train ~ trend + season + covid, lambda = 0)
round(coef(fit), 4)

#| **Turn the seasonal coefficients into percentages.** `exp(b) - 1` is the exact % gap from January. December is the giant, but notice February sits *below* January: it has fewer shopping days.
seas <- 100 * (exp(coef(fit)[grep("season", names(coef(fit)))]) - 1)
names(seas) <- month.abb[2:12]
viz_bars(seas, sort = FALSE, xlab = "% above or below January",
         title = "December sales run about 25% above January")

#| **Forecast the test period.** The regression needs a value for every predictor in every future month. Trend and season are known in advance (we always know next December is a December), and we set the COVID dummy to 0. That is what makes this an honest, *ex-ante* forecast.
fc <- forecast(fit, newdata = data.frame(covid = rep(0, length(test))))
viz_forecast(fc, actual = test, from = 2019, fitted = TRUE,
             title = "Trend + seasonal dummies follow the calendar, running a little high")

#| **Score it against the seasonal naive benchmark.** Every new model has to earn its row on the Chapter 3 scorecard. A negative ME means the forecast was too high on average.
sn <- snaive(train, h = length(test))
scores <- rbind(`Trend + season regression` = accuracy(fc, test)["Test set", c("ME", "MAE", "RMSE", "MAPE", "MASE")],
                `Seasonal naive` = accuracy(sn, test)["Test set", c("ME", "MAE", "RMSE", "MAPE", "MASE")])
viz_table(scores, highlight = c("MAE", "RMSE", "MAPE", "MASE"), digits = 2,
          title = "Retail sales scorecard, test period 2024 onward")

#| **Residual diagnostics.** `checkresiduals()` runs the Breusch–Godfrey test for autocorrelation in regression residuals. A tiny p-value says the misses come in long runs: a straight trend cannot follow the post-2021 surge in prices and spending. Chapter 7 fixes this with *dynamic regression* (regression with ARIMA errors).
checkresiduals(fit, plot = FALSE)

#| **Fourier terms: a smoother way to model the calendar.** Instead of 11 dummies, `fourier(train, K)` adds K pairs of sine and cosine waves with periods of 12, 6, 4, … months. Small K gives a smooth seasonal shape with few coefficients; K = 6 reproduces the dummies exactly. `CV()` scores each version; lower AICc and BIC are better. (Its leave-one-out `CV` column is `Inf` here: leaving out April 2020 leaves the pulse dummy with no data at all. A pulse dummy and leave-one-out CV do not mix.)
cv_tab <- NULL
for (K in c(1, 2, 3, 4, 6)) {
  waves <- fourier(train, K = K)
  cv_tab <- rbind(cv_tab, CV(tslm(train ~ trend + waves + covid, lambda = 0)))
}
cv_tab <- rbind(cv_tab, CV(fit))
rownames(cv_tab) <- c(paste0("Fourier K = ", c(1, 2, 3, 4, 6)), "Seasonal dummies")
viz_table(cv_tab[, c("AICc", "BIC", "AdjR2")], highlight = c("AICc", "BIC"), digits = 2,
          title = "Retail needs the full seasonal shape: K = 6 matches the dummies")
