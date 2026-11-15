#| **Freeze the model at the end of 1999.** Fit the logit using only rows dated up to December 1999. Their targets run through December 2000, so the model never sees a single outcome from the test period (2001 on). Everything from 2000 on is the **test set**: three recessions (2001, 2008–09, 2020) and the long 2022–24 inversion.
#| A strict real-time forecaster in December 1999 would know outcomes only through 1999 (and, given the NBER's lag, not even those), so this test is still slightly kind to the model.
train <- known[known$date <= as.Date("1999-12-01"), ]
test  <- known[known$date >= as.Date("2000-01-01"), ]
fit <- glm(rec_ahead ~ spread, data = train, family = binomial)
coef(fit)

#| **Forecast the test months** with the frozen 1999 model. No refitting, no peeking.
test$p <- predict(fit, newdata = test, type = "response")
viz_ts(`P(recession), 1999 model` = ts(test$p, start = c(2001, 1), frequency = 12), recessions = TRUE, ylab = "probability",
       title = "A model frozen in 1999 flagged 2001 and 2008, then raised a long false alarm",
       subtitle = "Out-of-sample probability, dated at the month it forecasts; grey = NBER recession")

#| **Score functions**, written once so we can reuse them: AUC through the rank formula (equivalent to the area under the ROC curve), and the Brier score.
auc <- function(p, y) { r <- rank(p); n1 <- sum(y == 1); n0 <- sum(y == 0); (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0) }
brier <- function(p, y) mean((p - y)^2)

#| **Score two test windows.** The benchmark is climatology: always forecast the *training* base rate. Compare 2000–2019 with the full test period through October 2025.
score <- function(rows) {
  t <- test[rows, ]
  c(months = nrow(t), AUC = auc(t$p, t$rec_ahead), Brier = brier(t$p, t$rec_ahead),
    `Brier, climatology` = brier(mean(train$rec_ahead), t$rec_ahead))
}
oos <- rbind(`2000–2019` = score(test$date <= as.Date("2019-12-01")), `2000–Oct 2025` = score(TRUE))
oos
viz_table(oos, highlight = c("Brier", "Brier, climatology"), digits = 3,
          title = "The 2022–24 false alarm turns a skillful model into one that loses to a constant")

#| **Where did the damage come from?** Sum the squared errors by the year the forecast was made. The biggest totals come from 2007 and 2008 (forecasts that missed the timing of the Great Recession) and from 2023 and 2024 (the long false alarm).
yr <- format(test$date, "%Y")
loss <- tapply((test$p - test$rec_ahead)^2, yr, sum)
round(sort(loss, decreasing = TRUE)[1:5], 2)
