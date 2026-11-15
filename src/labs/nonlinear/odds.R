#| **Fit the logit on the training clients.** `family = binomial` tells `glm()` that the target is 0/1 and to use the logistic link. (The hidden setup loaded the data and made the same split as the previous lab.) The coefficients are on the **log-odds** scale: positive means "raises the odds of a yes", negative "lowers them".
logit <- glm(yes ~ age + contact + campaign + poutcome + euribor3m,   # logistic regression
             family = binomial, data = train)
summary(logit)$coefficients                # estimates, standard errors, z values, p-values

#| **Translate to odds ratios.** `exp(coef)` turns each slope into the factor that multiplies the odds when the predictor rises by one unit. `confint.default()` gives Wald 95% intervals (estimate ± 1.96 standard errors), which we exponentiate too. An odds ratio above 1 raises the odds; below 1 lowers them; an interval that straddles 1 means "can't tell".
or_table <- data.frame(odds_ratio = exp(coef(logit)), exp(confint.default(logit)))   # odds ratio = exp(coef)
names(or_table) <- c("odds_ratio", "lower_95", "upper_95")
round(or_table, 3)

#| **Read them as a manager would.** Each one-point rise in Euribor multiplies the odds of a yes by about 0.66 (a 34% cut). Each extra call to the client in this campaign goes with odds about 0.91 times as high (an association: clients who said yes early were not called again). A client whose *previous* campaign ended in success has about 6.4 times the odds of a never-contacted client, other things equal.
viz_bars(round(exp(coef(logit))[-1], 2), title = "A past success multiplies the odds of a yes by about six",   # [-1] drops the intercept
         xlab = "Odds ratio (1 = no effect)", source = src)

#| **From odds back to probabilities.** Two example clients, identical except for the previous campaign's outcome. `predict(type = "response")` returns probabilities. Note that a 6.4× change in *odds* is not a 6.4× change in probability.
two <- data.frame(age = 40, contact = "cellular", campaign = 1, euribor3m = 4.9,   # two rows: same facts...
                  poutcome = c("nonexistent", "success"))   # ...except the previous outcome
p_two <- predict(logit, newdata = two, type = "response")   # probability of yes for each
round(p_two, 3)

#| **Marginal effects are not constant.** The slope of the S-curve is $b \cdot p(1-p)$, so it depends on where each client sits. The **average marginal effect** (AME) averages it over all clients; the **marginal effect at the mean** (MEM) evaluates it once, for a made-up "average client". For Euribor (in percentage points of probability per point of Euribor):
b <- coef(logit)["euribor3m"]              # Euribor slope on the log-odds scale
p <- fitted(logit)                         # each training client's fitted probability
ame <- mean(b * p * (1 - p))               # AME: slope at each client, averaged
x_bar <- colMeans(model.matrix(logit))     # the "average client": mean of every predictor column
p_bar <- plogis(sum(x_bar * coef(logit)))  # plogis() turns log-odds into a probability
mem <- b * p_bar * (1 - p_bar)             # MEM: slope at the average client
round(100 * c(AME = ame, MEM = unname(mem)), 2)   # x100 = percentage points

#| **For a yes/no predictor, use a discrete change.** Switch every training client's previous outcome to "success", then to "nonexistent", and average the difference in predicted probabilities. This is the AME of a past success, in percentage points.
# transform() copies train with poutcome replaced; factor(..., levels) keeps the same categories
p_succ <- predict(logit, transform(train, poutcome = factor("success", levels(train$poutcome))), type = "response")
p_none <- predict(logit, transform(train, poutcome = factor("nonexistent", levels(train$poutcome))), type = "response")
round(100 * mean(p_succ - p_none), 1)      # average change, in percentage points
