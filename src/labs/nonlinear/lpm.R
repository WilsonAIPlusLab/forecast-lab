#| **Load the clients.** Each row is one client of a Portuguese bank who was phoned in a marketing campaign. The target `y` says whether the client subscribed to a term deposit. We code it as `yes` = 1 or 0, the form every model in this chapter needs. Only about 11% said yes.
bank <- read.csv("data/bank_marketing.csv", stringsAsFactors = TRUE)
bank$yes <- as.integer(bank$y == "yes")
bank$poutcome <- relevel(bank$poutcome, ref = "nonexistent")
src <- "UCI Bank Marketing (Moro, Cortez & Rita 2014), CC BY 4.0"   # credit line for charts
mean(bank$yes)

#| **Hold out a test set, stratified by outcome.** The file has no dates and its rows are in random order (UCI drew this 10% sample at random), so a time split is impossible. Instead we keep 30% of the *yes* clients and 30% of the *no* clients aside: `pos` counts each client's position within its own class, and positions 0, 1, 2 of every 10 go to the test set. This gives the same stratified split in R and Python. In your own projects use `set.seed()` and `sample()`.
pos <- ave(seq_len(nrow(bank)), bank$y, FUN = seq_along) - 1
is_test <- pos %% 10 < 3
train <- bank[!is_test, ]
test  <- bank[is_test, ]
c(train = nrow(train), test = nrow(test), yes_train = sum(train$yes), yes_test = sum(test$yes))

#| **Three models, same five pre-call facts.** Age, phone type (`contact`), number of calls to the client in this campaign, counting the last one (`campaign`), the outcome of the previous campaign (`poutcome`) and the 3-month Euribor interest rate on the day of the call. `lm()` is the **linear probability model** (LPM); `glm(..., family = binomial)` fits a **logit**; `binomial(link = "probit")` fits a **probit**. All three are fitted on the training clients only.
f <- yes ~ age + contact + campaign + poutcome + euribor3m
lpm    <- lm(f, data = train)
logit  <- glm(f, family = binomial, data = train)
probit <- glm(f, family = binomial(link = "probit"), data = train)

#| **Count the impossible predictions.** A probability must lie between 0 and 1. The straight line does not know that: look at how many training clients get a *negative* probability of saying yes. The logit and probit can never leave the interval, by construction.
p_lpm <- fitted(lpm); p_logit <- fitted(logit); p_probit <- fitted(probit)
data.frame(model = c("LPM", "Logit", "Probit"),
           below_0 = c(sum(p_lpm < 0), sum(p_logit < 0), sum(p_probit < 0)),
           above_1 = c(sum(p_lpm > 1), sum(p_logit > 1), sum(p_probit > 1)),
           min = c(min(p_lpm), min(p_logit), min(p_probit)),
           max = c(max(p_lpm), max(p_logit), max(p_probit)))

#| **See it.** Each dot is one client: the logit's probability across, the LPM's up. Dots below the zero line are impossible forecasts. The two models agree in the middle; they part ways at the extremes, where the straight line overshoots.
viz_scatter(p_logit, p_lpm, fit = FALSE, xlab = "Logit probability", ylab = "LPM probability",
            title = "The straight line predicts negative probabilities for some clients",
            source = src)

#| **But do they rank clients differently?** Here is a twist. The share of correctly ordered (yes, no) pairs, the AUC you will meet later in the chapter, is almost identical for all three on the **test** clients. The LPM's problem is not *who* it ranks first; it is that its numbers are not usable as probabilities.
auc <- function(p, y) { r <- rank(p); n1 <- sum(y); n0 <- length(y) - n1
  (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0) }
c(LPM = auc(predict(lpm, test), test$yes),
  Logit = auc(predict(logit, test, type = "response"), test$yes),
  Probit = auc(predict(probit, test, type = "response"), test$yes))
