.m <- glm(yes ~ age + contact + campaign + poutcome + euribor3m, family = binomial, data = train)
.p <- predict(.m, newdata = test, type = "response")
.call <- .p >= quantile(.p, 0.80)
.rec <- sum(.call & test$yes == 1) / sum(test$yes == 1)
.prec <- sum(.call & test$yes == 1) / sum(.call)
.ok_p <- exists("p") && is.numeric(p) && length(p) == nrow(test) && all(p >= 0 & p <= 1)
check_that(.ok_p && exists("recall") && abs(recall - .rec) < 1e-9 && exists("precision") && abs(precision - .prec) < 1e-9,
  sprintf("Calling %d clients (20%% of the list) reaches %.0f%% of all subscribers, %.1f times what random calling would find: that ratio is the lift. Precision is %.0f%% against an %.0f%% base rate, and precision divided by the base rate is the same %.1f. Lift and precision are two views of one fact. Now change 0.80 to 0.70: how many more subscribers do the extra calls find?",
          sum(.call), 100 * .rec, .rec / 0.2, 100 * .prec, 100 * mean(test$yes), .prec / mean(test$yes)),
  if (!.ok_p) "Your p is not a vector of probabilities between 0 and 1. A logit needs family = binomial, and predict() needs type = \"response\" to return probabilities instead of log-odds." else
  "Recall divides the subscribers you reached by ALL subscribers in the test set: sum(test$yes == 1).")
