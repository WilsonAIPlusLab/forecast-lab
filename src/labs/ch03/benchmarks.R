#| **Load the data and split it in time.** We pretend it is the end of 2022: everything up to Dec 2022 is the **training set**, and 2023 onward is the **test set** we hide from every model. Never split a time series randomly; the test set must come *after* the training set.
retail <- fred("RSXFSN", start = 2010)
train  <- window(retail, end = c(2022, 12))
test   <- window(retail, start = c(2023, 1))
h      <- length(test)

#| **Four benchmark forecasts**, one line each. These are the methods any serious model must beat:
#| - `meanf`: the average of all history
#| - `naive`: the last observed value
#| - `snaive`: the value from the same month last year
#| - `rwf(drift = TRUE)`: a straight line from the first to the last observation
library(forecast)
f_mean   <- meanf(train, h = h)
f_naive  <- naive(train, h = h)
f_snaive <- snaive(train, h = h)
f_drift  <- rwf(train, h = h, drift = TRUE)

#| **Plot all four against what actually happened** (gold, dashed). Seasonal naive copies the December peaks and January dips; mean, naive and drift draw flat or straight lines straight through them.
viz_compare(history = window(train, start = 2019), actual = test,
            Mean = f_mean, Naive = f_naive, `Seasonal naive` = f_snaive, Drift = f_drift,
            title = "Only seasonal naive tracks the December peaks and January dips")

#| **Score each method on the test set.** `accuracy(forecast, test)` returns a matrix with a "Training set" row and a "Test set" row. We keep only the test-set row, because only out-of-sample accuracy counts.
score <- function(f) accuracy(f, test)["Test set", c("ME", "MAE", "RMSE", "MAPE", "MASE")]
scores <- rbind(Mean = score(f_mean), Naive = score(f_naive),
                `Seasonal naive` = score(f_snaive), Drift = score(f_drift))
scores

#| **Turn it into a scorecard.** Green cells mark the winner on each metric. Seasonal naive wins every one, with an MAE of about 25 billion dollars a month (the data are in millions of dollars). Its MASE is about 1.04: in the test period it missed by slightly more than seasonal naive did, on average, in the training data. This table is the yardstick for the rest of the course: every new model gets a row, and it has to beat the best benchmark.
viz_table(scores, highlight = c("MAE", "RMSE", "MAPE", "MASE"), digits = 2,
          title = "Seasonal naive wins the retail scorecard, 2023 onward")
