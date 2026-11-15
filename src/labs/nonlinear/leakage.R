#| **The honest model**, as before: five facts the bank knows *before* it dials. Its test AUC is our baseline.
auc <- function(p, y) { r <- rank(p); n1 <- sum(y); n0 <- length(y) - n1
  (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0) }
honest <- glm(yes ~ age + contact + campaign + poutcome + euribor3m, family = binomial, data = train)
auc(predict(honest, test, type = "response"), test$yes)

#| **Add one more column: `duration`, the length of the call in seconds.** Same split, same test clients. Watch the AUC.
leaky <- glm(yes ~ age + contact + campaign + poutcome + euribor3m + duration, family = binomial, data = train)
auc(predict(leaky, test, type = "response"), test$yes)

#| **Too good to be true? Look at why.** The median subscriber's call lasts almost three times as long as a non-subscriber's (458 against 165 seconds), because agreeing to a deposit takes a conversation. Not one of the 407 calls shorter than a minute ended in a yes. The column is not a *predictor* of the answer; it is partly a *record* of the answer.
aggregate(duration ~ y, data = bank, FUN = median)
c(calls_under_60s = sum(bank$duration < 60), yes_among_them = sum(bank$duration < 60 & bank$yes == 1))

#| **The forecasting test: would you know it in time?** You must decide whom to call *before* calling, so the call's length does not exist yet. The dataset's own documentation says this column should be used only for benchmarking and discarded for a realistic predictive model. Odds ratio per extra minute of call:
exp(60 * coef(leaky)["duration"])

#| **The lesson in one chart.** Same model, same clients, one leaked column. A jump like this should trigger suspicion, not celebration.
viz_bars(c(`Before the call (honest)` = auc(predict(honest, test, type = "response"), test$yes),
           `With call duration (leak)` = auc(predict(leaky, test, type = "response"), test$yes)),
         sort = FALSE, xlab = "Test AUC (0.5 = coin flip, 1 = perfect)",
         title = "One leaked column turns a decent model into a 'miracle'", source = src)
