#| **The log-likelihood scores any candidate curve.** For each month, a curve gives a probability p of "recession in 12 months". If a recession did follow, the month adds log(p) to the score; if not, it adds log(1 − p). Both are negative, so the best curve is the one whose total is closest to zero. `known` (the months whose 12-month-ahead answer is known) is rebuilt for you in hidden setup code.
y <- known$rec_ahead                     # 0/1 outcome: recession 12 months later?
s <- known$spread                        # today's 10y minus 3m spread, pct. points
loglik <- function(a, b) {               # total log-likelihood of the curve p = 1 / (1 + exp(-(a + b*s)))
  p <- plogis(a + b * s)                 # plogis() is the logistic S-curve
  sum(y * log(p) + (1 - y) * log(1 - p))
}
# three candidates: a coin flip for every month, the base rate for every month, and a rough guess that uses the spread
c(coin_flip = loglik(0, 0), base_rate = loglik(qlogis(mean(y)), 0), rough_guess = loglik(-1, -1))

#| **Maximum likelihood by hand: IRLS.** No formula gives the best (a, b) directly, so `glm()` climbs the log-likelihood step by step. Each step is a weighted least-squares regression: months with p near 0.5 (weight p(1 − p) = 0.25) count most. Start from a = b = 0 and watch the estimates settle within a few steps.
X <- cbind(1, s)                         # design matrix: a column of 1s (intercept) and the spread
beta <- c(0, 0)                          # starting values: a coin flip for every month
for (step in 1:6) {
  p <- as.vector(plogis(X %*% beta))     # current probabilities
  w <- p * (1 - p)                       # IRLS weights: the variance of a 0/1 outcome
  beta <- beta + solve(t(X) %*% (w * X), t(X) %*% (y - p))   # Newton step: (X'WX)^-1 X'(y - p)
  cat(sprintf("step %d: a = %8.5f  b = %8.5f  log-likelihood = %9.3f\n", step, beta[1], beta[2], loglik(beta[1], beta[2])))
}
logit <- glm(rec_ahead ~ spread, data = known, family = binomial)   # R's built-in version of the same algorithm
coef(logit)

#| **See the peak.** Hold the intercept at its best value and slide the slope. The log-likelihood is a smooth hill, and `glm()` sits on top of it. A steeper hill around the top means the data pin the slope down more precisely: that curvature is where the standard errors come from.
bs <- seq(-2.2, 0.2, by = 0.05)          # candidate slopes
a_hat <- coef(logit)[1]                  # best intercept
viz_lines(bs, `Log-likelihood` = sapply(bs, function(b) loglik(a_hat, b)), xlab = "Slope b on the spread", ylab = "Log-likelihood",
          title = "Maximum likelihood: glm() picks the slope at the top of the hill")

#| **Does the spread help at all? The likelihood-ratio test.** Compare the fitted model with the base-rate-only model. Twice the gain in log-likelihood follows a chi-squared distribution with 1 degree of freedom (one extra coefficient) if the spread is useless. **McFadden's pseudo-R²** is 1 − ℓ(model) / ℓ(base rate): the share of the "badness" of the constant forecast that the model removes. It is not an R² of a straight line, and values of 0.2 to 0.4 already count as a good fit.
ll_model <- as.numeric(logLik(logit))    # log-likelihood at the maximum
ll_null  <- loglik(qlogis(mean(y)), 0)   # base-rate-only model (same as glm(rec_ahead ~ 1))
LR <- 2 * (ll_model - ll_null)           # likelihood-ratio statistic
c(LR = LR, p_value = pchisq(LR, df = 1, lower.tail = FALSE), mcfadden_R2 = 1 - ll_model / ll_null)

#| **Honest standard errors for overlapping targets.** Each row's target looks 12 months ahead, so neighboring rows share 11 of those 12 future months and their errors move together. `glm()` assumes independent rows, so its standard errors are too small. The **Newey–West (HAC)** fix keeps the same coefficients but adds up how each month's score contribution x(y − p) co-moves with its neighbors', with weights that fade over L lags.
p <- fitted(logit)                       # fitted probabilities
g <- X * (y - p)                         # score contributions: one row per month
bread <- solve(t(X) %*% (p * (1 - p) * X))   # inverse of the curvature (= glm's usual covariance)
L <- 24                                  # lags to include: at least the 11-month overlap, plus room for slow-moving errors
meat <- crossprod(g)                     # lag 0: sum of g_t g_t'
for (l in seq_len(L)) {             # seq_len(0) is empty, so L = 0 also works
  G <- t(g[-(1:l), ]) %*% g[1:(nrow(g) - l), ]   # sum of g_t g_{t-l}'
  meat <- meat + (1 - l / (L + 1)) * (G + t(G))   # Bartlett weights fade from 1 toward 0
}
se_naive <- sqrt(diag(bread))            # glm()'s standard errors
se_hac   <- sqrt(diag(bread %*% meat %*% bread))   # sandwich: bread x meat x bread
round(cbind(estimate = coef(logit), se_naive, se_hac, ratio = se_hac / se_naive, z_hac = coef(logit) / se_hac), 3)

#| **Why so much wider? The errors come in long runs.** Correlate each month's leftover error y − p with the previous month's. Then check that the Newey–West answer barely depends on the exact number of lags.
r <- y - p                               # leftover errors
cor(r[-1], r[-length(r)])                # correlation between neighboring months
nw_se <- function(L) {                   # Newey-West standard error of the slope for a given number of lags
  meat <- crossprod(g)
  for (l in seq_len(L)) { G <- t(g[-(1:l), ]) %*% g[1:(nrow(g) - l), ]; meat <- meat + (1 - l / (L + 1)) * (G + t(G)) }
  unname(sqrt(diag(bread %*% meat %*% bread))[2])
}
round(c(lags_0 = nw_se(0), lags_12 = nw_se(12), lags_24 = nw_se(24), lags_36 = nw_se(36)), 3)
