# The data frame d (date, spread, rec, rec_ahead) is ready, as in the labs above.
# rec_ahead asks: "is month t + 12 a recession month?"
# Build a different target, rec_within: "is there ANY recession month in t + 1, ..., t + 12?"
n <- nrow(d)
d$rec_within <- sapply(1:n, function(i) if (i + 12 > n) NA else max(d$rec[(i + 1):(i + ______)]))

# 1. Fit a logit of rec_within on the spread
fit_w <- glm(rec_within ~ spread, data = d, family = ______)

# 2. Score it with the AUC (fit_w$y holds the outcomes glm actually used)
auc <- function(p, y) { r <- rank(p); n1 <- sum(y == 1); n0 <- sum(y == 0); (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0) }
auc_w <- auc(fitted(fit_w), fit_w$y)
auc_w
