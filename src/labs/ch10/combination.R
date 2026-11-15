#| **One series first.** Train on total retail sales 2010–2017 (`RSXFSN`, $ millions, NSA) and forecast 2018–2019. Three methods: ETS with multiplicative seasonality (`model = "ZZM"`: seasonal swings in retail grow with the level of sales, and ETS still picks the error and trend types itself), the classic "airline" seasonal ARIMA(0,1,1)(0,1,1) on logs (`lambda = 0`), and seasonal naive. The **combination** is their simple average, month by month.
library(forecast)
retail <- fred("RSXFSN", start = 2010)
train <- window(retail, end = c(2017, 12))
test  <- window(retail, start = c(2018, 1), end = c(2019, 12))
f_ets   <- forecast(ets(train, model = "ZZM", damped = FALSE), h = 24)$mean
f_arima <- forecast(Arima(train, order = c(0, 1, 1), seasonal = c(0, 1, 1), lambda = 0, biasadj = TRUE), h = 24)$mean
f_snaive <- snaive(train, h = 24)$mean
f_combo <- (f_ets + f_arima + f_snaive) / 3
viz_compare(history = window(train, start = 2015), actual = test,
            ETS = f_ets, ARIMA = f_arima, `Seasonal naive` = f_snaive, Combination = f_combo,
            title = "Three forecasts and their average, 2018–2019")

#| **Score with MASE** (Chapter 3): mean absolute error divided by the in-sample error of seasonal naive. Below 1 beats that benchmark. On this one series ETS wins, and the combination comes third, pulled up by the weak seasonal naive forecast.
mase <- function(f, tr, te) mean(abs(te - f)) / mean(abs(diff(tr, lag = 12)))
round(c(ETS = mase(f_ets, train, test), ARIMA = mase(f_arima, train, test),
        `Seasonal naive` = mase(f_snaive, train, test), Combination = mase(f_combo, train, test)), 3)

#| **One series proves nothing.** Wrap the whole recipe in a function and run it on eight retail series: the total plus seven store categories (all NSA, $ millions). Same split for all: train 2010–2017, test 2018–2019.
score_series <- function(id) {
  y <- fred(id, start = 2010)
  tr <- window(y, end = c(2017, 12)); te <- window(y, start = c(2018, 1), end = c(2019, 12))
  e <- forecast(ets(tr, model = "ZZM", damped = FALSE), h = 24)$mean
  a <- forecast(Arima(tr, order = c(0, 1, 1), seasonal = c(0, 1, 1), lambda = 0, biasadj = TRUE), h = 24)$mean
  s <- snaive(tr, h = 24)$mean
  c(ETS = mase(e, tr, te), ARIMA = mase(a, tr, te), `Seasonal naive` = mase(s, tr, te), Combination = mase((e + a + s) / 3, tr, te))
}
ids <- c(`Total retail` = "RSXFSN", Clothing = "MRTSSM448USN", `Sporting goods` = "MRTSSM451USN",
         Electronics = "MRTSSM443USN", `Building materials` = "MRTSSM444USN", `General merchandise` = "MRTSSM452USN",
         `Health & personal care` = "MRTSSM446USN", Furniture = "MRTSSM442USN")
board <- t(sapply(ids, score_series))
round(board, 2)

#| **The scorecard.** Flip the table so each column is a series and green marks the winner in that column. The last column averages MASE across the eight series. Look for two things: which method has the lowest average, and which method is never the worst.
card <- cbind(t(board), Average = colMeans(board))
viz_table(card, highlight = colnames(card), digits = 2,
          title = "The simple average was never the worst and had the lowest average error")

#| **Count wins and losses.** "Best" is the lowest MASE on a series; "worst" is the highest.
rbind(best  = table(factor(colnames(board)[apply(board, 1, which.min)], levels = colnames(board))),
      worst = table(factor(colnames(board)[apply(board, 1, which.max)], levels = colnames(board))))
