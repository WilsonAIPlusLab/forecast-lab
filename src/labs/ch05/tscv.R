#| **Back to the Chapter 3 scorecard.** Total U.S. retail sales excluding food services ($ millions, NSA), 2012 to 2019. We stop before COVID so a one-off shock doesn't decide the contest. In Chapter 3, seasonal naive was the benchmark to beat on this series.
library(forecast)
retail <- fred("RSXFSN", start = 2012, end = c(2019, 12))

#| **Which ETS model?** We let `ets()` choose once, on the first six years only, so the choice itself uses no future data.
ets(window(retail, end = c(2017, 12)))$method

#| **Wrap the model in a forecasting function.** `tsCV()` needs a function that takes the data so far and a horizon `h`, and returns a forecast. Ours re-estimates the ETS(M,A,M) chosen above at every origin, exactly as you would in production.
f_ets <- function(x, h) forecast(ets(x, model = "MAM"), h = h)

#| **Roll the origin forward.** `initial = 72` means the first forecast is made with six years of data; after that the origin moves one month at a time. The ETS fit is repeated at every origin, which is why this line takes a few seconds.
e_ets    <- tsCV(retail, f_ets,  h = 12, initial = 72)
e_snaive <- tsCV(retail, snaive, h = 12, initial = 72)

#| **Error by horizon.** MAE in $ millions at 1 to 12 months ahead. ETS's error is 30% to 50% below seasonal naive's at every horizon (about 8.0 billion dollars against 15.6 billion one month ahead). With 96 months of data and a 72-month first window, each horizon is scored on only 12 to 23 forecasts, so treat small wiggles as noise.
mae <- rbind(ETS = colMeans(abs(e_ets), na.rm = TRUE),
             `Seasonal naive` = colMeans(abs(e_snaive), na.rm = TRUE))
round(mae)
viz_lines(1:12, ETS = mae["ETS", ], `Seasonal naive` = mae["Seasonal naive", ],
          xlab = "months ahead", ylab = "MAE ($ millions)", zero = TRUE,
          title = "ETS beats seasonal naive at every horizon")

#| **Is the gap real?** The Diebold–Mariano test from Chapter 3, on one-step-ahead errors. A small p-value says ETS is genuinely more accurate than seasonal naive here, not just lucky.
ok <- !is.na(e_ets[, 1]) & !is.na(e_snaive[, 1])
dm.test(e_ets[ok, 1], e_snaive[ok, 1], h = 1)
