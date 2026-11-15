#| **Score the clients the model has never seen.** Fit on the training clients, then predict a probability of "yes" for each of the 1,237 test clients. Treat the test set as the next campaign's call list: the model knew nothing about these people.
logit <- glm(yes ~ age + contact + campaign + poutcome + euribor3m, family = binomial, data = train)
p <- predict(logit, newdata = test, type = "response")
y <- test$yes
summary(p)

#| **A confusion matrix at the default threshold of 0.5.** Predict "yes" when the probability exceeds 0.5. `table()` cross-tabulates predictions against what really happened. Very few clients ever reach 50%, so the model almost never says yes.
pred50 <- as.integer(p > 0.5)
table(predicted = pred50, actual = y)

#| **Five metrics from one table.** We write a small function so every number is visible: **accuracy** (share correct), **precision** (of those we call "yes", how many are?), **recall** or sensitivity (of the real yeses, how many did we catch?), **specificity** (of the real noes, how many did we leave alone?) and **F1** (the harmonic mean of precision and recall).
metrics <- function(pred, y) {
  TP <- sum(pred == 1 & y == 1); FP <- sum(pred == 1 & y == 0)
  FN <- sum(pred == 0 & y == 1); TN <- sum(pred == 0 & y == 0)
  precision <- if (TP + FP > 0) TP / (TP + FP) else NA
  recall <- TP / (TP + FN)
  c(TP = TP, FP = FP, FN = FN, TN = TN, accuracy = (TP + TN) / length(y), precision = precision,
    recall = recall, specificity = TN / (TN + FP), F1 = 2 * precision * recall / (precision + recall))
}

#| **The accuracy paradox.** Compare four rules: the model at 0.5, the model at a *business* threshold of 0.10, calling everyone, and a "model" that always says no. Always-no is 89% accurate and useless: it finds zero subscribers. The 0.10 threshold comes from economics, not statistics: if a call costs \$5 and a new deposit is worth \$50 to the bank (illustrative numbers), a call pays off when $p \times 50 > 5$, that is, when $p > 0.10$. The `profit` column applies those numbers.
scores <- rbind(`Logit, threshold 0.5` = metrics(pred50, y),
                `Logit, threshold 0.10` = metrics(as.integer(p > 0.10), y),
                `Call everyone` = metrics(rep(1L, length(y)), y),
                `Always say no` = metrics(rep(0L, length(y)), y))
scores <- cbind(scores, profit = 50 * scores[, "TP"] - 5 * (scores[, "TP"] + scores[, "FP"]))
round(scores, 3)

#| **The ROC curve, by hand.** Sort clients from highest to lowest probability and lower the threshold one client at a time. At each step, the true-positive rate (recall) is the share of yeses caught so far; the false-positive rate (1 − specificity) is the share of noes called by mistake. Plotting one against the other traces the ROC curve.
o <- order(p, decreasing = TRUE)
tpr <- c(0, cumsum(y[o] == 1) / sum(y == 1))
fpr <- c(0, cumsum(y[o] == 0) / sum(y == 0))
grid <- seq(0, 1, by = 0.01)
viz_lines(grid, Logit = approx(fpr, tpr, xout = grid, ties = max)$y, `Coin flip` = grid,
          xlab = "False-positive rate (share of non-buyers called)", ylab = "True-positive rate (share of buyers reached)",
          title = "The model's ROC curve bows well above a coin flip", source = src)

#| **AUC = area under that curve.** The trapezoid rule adds up the area. It equals the probability that a randomly chosen subscriber gets a higher score than a randomly chosen non-subscriber. 0.5 is a coin flip; 1 is perfect ranking.
auc <- sum(diff(fpr) * (head(tpr, -1) + tail(tpr, -1)) / 2)
auc

#| **The gain table: what a marketing manager actually wants.** Split the ranked list into ten deciles. **Cumulative gain** is the share of all subscribers found by calling down to that decile; **lift** is how many times better that is than calling at random. A Gini coefficient, 2·AUC − 1, summarizes the same curve (FYI: credit-scoring teams report it).
decile <- ceiling(10 * seq_along(o) / length(o))
gain <- data.frame(called = paste0(10 * (1:10), "%"),
                   buyers = as.vector(tapply(y[o], decile, sum)))
gain$cum_gain <- cumsum(gain$buyers) / sum(y)
gain$lift <- gain$cum_gain / (1:10 / 10)
gain
c(gini = 2 * auc - 1)

#| **Is that AUC luck?** One test set of 136 subscribers is small. Redo the whole experiment on 50 different random stratified splits (`set.seed()` makes them reproducible) and look at the spread of test AUCs. Report a range, not just one number.
auc_fun <- function(p, y) { r <- rank(p); n1 <- sum(y); n0 <- length(y) - n1; (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0) }
set.seed(3371)
aucs <- replicate(50, {
  te <- c(sample(which(bank$yes == 1), 136), sample(which(bank$yes == 0), 1101))
  m <- glm(yes ~ age + contact + campaign + poutcome + euribor3m, family = binomial, data = bank[-te, ])
  auc_fun(predict(m, bank[te, ], type = "response"), bank$yes[te])
})
round(quantile(aucs, c(0.05, 0.5, 0.95)), 3)
