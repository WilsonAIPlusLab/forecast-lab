# The data frame d (date, spread, rec, rec_ahead) is ready, as in the labs above.
# rec_ahead asks: "is month t + 12 a recession month?"
# Build a different target, rec_within: "is there ANY recession month in t + 1, ..., t + 12?"
n <- nrow(d)                         # number of months
# For each row i: max() of the next 12 months' 0/1 values is 1 if any is a recession; NA if the window runs past the data
d$rec_within <- sapply(1:n, function(i) if (i + 12 > n) NA else max(d$rec[(i + 1):(i + 12)]))

# 1. Fit a logit of rec_within on the spread
fit_w <- glm(rec_within ~ spread, data = d, family = binomial)   # binomial = 0/1 outcome, logit link by default

# 2. Score it with the AUC (fit_w$y holds the outcomes glm actually used)
# AUC via ranks: chance a random recession-window month gets a higher p than a random calm month
auc <- function(p, y) { r <- rank(p); n1 <- sum(y == 1); n0 <- sum(y == 0); (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0) }
auc_w <- auc(fitted(fit_w), fit_w$y) # fitted() = in-sample probabilities
auc_w                                # 0.5 = coin flip, 1 = perfect
