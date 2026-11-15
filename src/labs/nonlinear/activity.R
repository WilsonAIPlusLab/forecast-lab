# Instructor activity check (run with tools/check_lab.R after setup_bank.R): best call share for several
# cost/value assumptions, using the chapter's five-fact logit on the 1,237 test clients.
logit <- glm(yes ~ age + contact + campaign + poutcome + euribor3m, family = binomial, data = train)
p <- predict(logit, test, type = "response"); y <- test$yes
o <- order(p, decreasing = TRUE); tp <- cumsum(y[o]); k <- seq_along(o)
plan <- function(cost, value) {
  prof <- value * tp - cost * k; b <- which.max(prof)
  data.frame(cost = cost, value = value, breakeven_p = cost / value, best_share = b / length(o), calls = b,
             subscribers = tp[b], profit = prof[b], threshold = p[o[b]], call_all = value * sum(y) - cost * length(y))
}
do.call(rbind, list(plan(5, 50), plan(5, 100), plan(8, 40), plan(5, 30)))
