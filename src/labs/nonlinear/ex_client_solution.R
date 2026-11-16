# Your manager asks about one client: a 40-year-old, reached on a mobile phone, on the first call
# of this campaign, with Euribor at 4.9%. "What are her chances, should we call her, and how much
# would it matter if our previous campaign with her had been a success?"
logit <- glm(yes ~ age + contact + campaign + poutcome + euribor3m,   # the chapter's five-fact logit
             family = binomial, data = train)

# Two versions of the same client: identical except for the previous campaign's outcome
her <- data.frame(age = 40, contact = "cellular", campaign = 1, euribor3m = 4.9,
                  poutcome = c("nonexistent", "success"))

# 1. Her probability of a yes, in each version ("response" = the probability scale)
p <- predict(logit, newdata = her, type = "response")

# 2. Odds = p / (1 - p); their ratio equals exp(coefficient), the odds ratio
odds <- p / (1 - p)
odds_ratio <- odds[2] / odds[1]            # "success" version over "never contacted" version

# 3. The same change in percentage points (pp) of probability
change_pp <- 100 * (p[2] - p[1])

# 4. Expected value of one call: chance of a yes x $50 per deposit, minus $5 per call
ev_call <- p * 50 - 5
round(c(p = p, odds_ratio = unname(odds_ratio), change_pp = unname(change_pp), ev_call = ev_call), 3)
