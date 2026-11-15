#| **Same data, same split.** E-commerce sales ($ millions, NSA), training through August 2025, the next 12 months held out.
library(forecast)                          # for ets(), forecast(), accuracy()
online <- fred("MRTSSM4541USN", start = 2015)   # U.S. e-commerce sales from Jan 2015
train  <- window(online, end = c(2025, 8))      # training set: through August 2025
test   <- window(online, start = c(2025, 9))    # test set: the 12 months from September 2025

#| **Let `ets()` choose the model.** With no options, `ets()` fits every sensible combination of **E**rror (A, M), **T**rend (N, A, Ad) and **S**eason (N, A, M), estimates each one by maximum likelihood, and keeps the one with the lowest **AICc**. Read the printout from the top:
#| - `ETS(M,A,M)`: multiplicative errors, additive (straight-line) trend, multiplicative seasonality.
#| - `alpha`, `beta`, `gamma`: how fast the level, slope and seasonal indices react to new data (0 = never, 1 = instantly).
#| - `sigma`: the typical one-step error. With multiplicative errors it is a *proportion*: 0.04 means a typical miss of about 4%.
fit <- ets(train)                          # automatic model selection by AICc
fit                                        # print the chosen model and its parameters

#| **Which candidates came close?** We refit the winner and four rivals by name and compare their AICc. Lower is better; differences of more than about 10 points are decisive. AICc rewards fit but charges for every extra parameter, so it guards against overfitting *without* touching the test set.
# model = "ANA" means Error A, Trend N, Season A; $aicc extracts each fit's AICc
aicc <- c(`ETS(A,N,A)`  = ets(train, model = "ANA")$aicc,
          `ETS(A,A,A)`  = ets(train, model = "AAA")$aicc,
          `ETS(M,N,M)`  = ets(train, model = "MNM")$aicc,
          `ETS(M,A,M)`  = ets(train, model = "MAM")$aicc,
          `ETS(M,Ad,M)` = ets(train, model = "MAM", damped = TRUE)$aicc)   # Ad = damped trend
round(sort(aicc))                          # smallest (best) first

#| **See the states the model is tracking.** An ETS model is a *state-space* model: behind the data sit a level, a slope and 12 seasonal indices that evolve month by month. The chart shows the data, the **level** (labelled trend), the **seasonal factor** applied each month, and the one-step errors, which are *relative* (−0.05 = 5% below the forecast) because the errors are multiplicative. Look at the seasonal panel: the December factor drifts down from about 1.42 (2015) to about 1.22 (2024). December has become a smaller share of the online year, and a γ near 0.5 lets the model follow that shift.
st <- fit$states                       # one row per month: level l, slope b, seasonal s1..s12
n  <- nrow(st)                         # rows = months + 1 (the first row holds the starting values)
states <- list(x        = train,
               trend    = ts(st[-1, "l"],  start = start(train), frequency = 12),   # level after each update
               seasonal = ts(st[-n, "s12"], start = start(train), frequency = 12),  # factor applied that month
               random   = residuals(fit))                                            # relative one-step errors
viz_decomp(states, title = "What ETS(M,A,M) tracks: a rising level and a fading holiday peak")

#| **Forecast with prediction intervals.** Because ETS is a statistical model with an explicit error term, `forecast()` can produce 80% and 95% **prediction intervals**, not just a line. The gold line is what actually happened.
fc <- forecast(fit, h = 12)                # 12 months ahead, with 80% and 95% intervals
viz_forecast(fc, actual = test, from = 2021,   # show 2021 onward
             title = "All 12 test months land inside the 95% interval")

#| **Did the intervals hold?** Count how many of the 12 test months fall inside the 95% interval, and score the point forecast.
inside <- test >= fc$lower[, "95%"] & test <= fc$upper[, "95%"]   # TRUE where actual is between the bounds
sum(inside)                                # TRUE counts as 1, so this counts months inside
round(accuracy(fc, test)["Test set", c("MAPE", "MASE")], 2)   # test-set accuracy of the point forecast
