#| **Fit a logit with `glm()`.** `family = binomial(link = "logit")` tells R that the target is 0/1 and that the probability follows the S-shaped logistic curve, so it always stays between 0 and 1. The data frame `d` (spread, recession indicator and the 12-month-ahead target) is rebuilt for you in hidden setup code. `known` holds the rows whose answer is already known.
logit <- glm(rec_ahead ~ spread, data = known, family = binomial(link = "logit"))   # P(recession in 12 months) vs spread
summary(logit)$coefficients          # estimates, standard errors, z-values, p-values

#| **Probit: the same idea with a different S-curve.** A probit uses the normal distribution's cumulative curve instead of the logistic one. This is the form the New York Fed uses. The coefficients are on a different scale (logit slopes are roughly 1.6 to 1.8 times probit slopes), but as you will see, the fitted probabilities are almost identical.
probit <- glm(rec_ahead ~ spread, data = known, family = binomial(link = "probit"))   # normal-CDF S-curve
coef(probit)
c(logLik_logit = logLik(logit), logLik_probit = logLik(probit))   # log-likelihoods: higher = better fit

#| **Read the logit slope as an odds ratio.** The logit says log(odds) = a + b × spread. So each extra percentage point of spread multiplies the **odds** of a recession a year later by exp(b). A number below 1 means a steeper curve makes recession less likely.
b <- coef(logit)["spread"]           # slope on the spread (change in log-odds per point)
exp(b)                               # odds ratio = exp(coef)

#| **Translate into probabilities.** `predict(..., type = "response")` returns probabilities, not log-odds. Compare a deeply inverted curve (-1), a flat one (0), and normal-to-steep ones.
grid <- data.frame(spread = c(-2, -1, 0, 1, 2, 3))   # spreads to evaluate, pct. points
# cbind() glues the grid and both models' probabilities into one table
cbind(grid, logit = predict(logit, grid, type = "response"), probit = predict(probit, grid, type = "response"))

#| **Marginal effect at a value.** How much does the probability change for a small change in spread? For a logit, the slope of the S-curve at a point is b × p × (1 − p). It is steepest where p = 0.5 and flat in the tails. Here it is at a flat curve (spread = 0) and at a steep one (spread = 2), in percentage points of probability per percentage point of spread.
p0 <- predict(logit, data.frame(spread = 0), type = "response")   # probability at a flat curve
p2 <- predict(logit, data.frame(spread = 2), type = "response")   # probability at a steep curve
100 * c(at_flat = b * p0 * (1 - p0), at_steep = b * p2 * (1 - p2))   # x 100: percentage points

#| **Draw the three curves.** The LPM line runs off below zero. Logit and probit bend to stay inside 0 to 1 and nearly overlap.
lpm <- lm(rec_ahead ~ spread, data = known)   # linear probability model, for comparison
s <- seq(-3, 4.5, by = 0.1)                   # fine grid of spreads for smooth curves
viz_lines(s, Logit = predict(logit, data.frame(spread = s), type = "response"),
          Probit = predict(probit, data.frame(spread = s), type = "response"),
          LPM = predict(lpm, data.frame(spread = s)),   # lm() predictions are already on the 0/1 scale
          xlab = "10y minus 3m spread today (pct. points)", ylab = "P(recession in 12 months)",
          title = "Logit and probit bend to stay between 0 and 1; the straight line does not")
