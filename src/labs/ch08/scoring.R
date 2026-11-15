#| **Fit the logit and get a probability for every month with a known answer.** `y` is the actual outcome (1 = the month 12 months later was a recession month). This lab scores the model *in sample*, on the same months it was fitted to. The next lab does it honestly, out of sample.
logit <- glm(rec_ahead ~ spread, data = known, family = binomial)   # logit: P(recession in 12 months) vs spread
p <- predict(logit, type = "response")   # fitted probabilities for the training months
y <- known$rec_ahead                     # actual 0/1 outcomes
c(months = length(y), recession_months = sum(y), base_rate = round(mean(y), 3))   # base rate = share of 1s

#| **Turn probabilities into yes/no calls with a threshold.** Call "recession ahead" whenever p ≥ 0.5. Then cross-tabulate the calls against what happened: this is the **confusion matrix**.
call <- as.numeric(p >= 0.5)             # 1 = "recession ahead" call, 0 = no call
table(Called = call, Actual = y)         # counts of each call/outcome combination

#| **Two rates summarize the matrix.**
#| - **Hit rate** (true positive rate, sensitivity): of the months that *were* followed by recession, the share we flagged.
#| - **False alarm rate** (false positive rate): of the calm months, the share we wrongly flagged.
#| A lower threshold raises both. There is no free lunch.
# p[y == 1] = probabilities in pre-recession months; mean() of TRUE/FALSE = share TRUE
rates <- function(th) c(threshold = th, hit_rate = mean(p[y == 1] >= th), false_alarm_rate = mean(p[y == 0] >= th))
rbind(rates(0.5), rates(0.3), rates(0.2))   # one row per threshold

#| **The ROC curve: every threshold at once.** Sweep the threshold from 1 down to 0 and plot hit rate against false alarm rate. A useless model sits on the diagonal; a perfect one hugs the top-left corner.
th  <- c(Inf, sort(unique(p), decreasing = TRUE), -Inf)   # every distinct p as a threshold, plus both extremes
tpr <- sapply(th, function(t) mean(p[y == 1] >= t))       # hit rate at each threshold
fpr <- sapply(th, function(t) mean(p[y == 0] >= t))       # false alarm rate at each threshold
viz_lines(fpr, `Yield-curve logit` = tpr, `Coin flip` = fpr, xlab = "False alarm rate", ylab = "Hit rate",   # coin flip = diagonal
          title = "The spread separates pre-recession months from calm ones far better than chance")

#| **AUC: the area under the ROC curve**, computed with the trapezoid rule. It has a neat meaning: the probability that a randomly chosen pre-recession month gets a *higher* p than a randomly chosen calm month. 0.5 is a coin flip, 1 is perfect.
auc <- sum(diff(fpr) * (head(tpr, -1) + tail(tpr, -1)) / 2)   # width x average height of each strip, summed
auc

#| **The Brier score judges the probabilities themselves**, not the yes/no calls: the mean squared gap between p and the 0/1 outcome. Lower is better. Compare it with a "climatology" forecast that always says the base rate. The **Brier skill score** is the share of that benchmark's error the model removes.
brier <- mean((p - y)^2)                 # model's Brier score
brier_climo <- mean((mean(y) - y)^2)     # always forecast the base rate
c(brier = brier, climatology = brier_climo, skill = 1 - brier / brier_climo)   # skill > 0 = beats climatology

#| **Calibration: when the model says 30%, does a recession follow about 30% of the time?** Group months by their forecast and compare the average forecast with the share that turned into recessions.
bins <- cut(p, breaks = c(0, 0.1, 0.2, 0.4, 0.6, 1), include.lowest = TRUE)   # assign each month to a probability range
# per range: number of months, average forecast, actual share followed by recession (tapply = apply within groups)
calib <- data.frame(`Forecast range` = levels(bins), Months = as.vector(table(bins)), `Average forecast` = as.vector(tapply(p, bins, mean)),
                    `Share followed by recession` = as.vector(tapply(y, bins, mean)), check.names = FALSE)
calib
viz_table(calib, digits = 3, title = "Well calibrated below 20%, overconfident above 40%")
