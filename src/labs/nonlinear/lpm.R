#| **Load the clients.** Each row is one client of a Portuguese bank who was phoned in a marketing campaign. The target `y` says whether the client subscribed to a term deposit. We code it as `yes` = 1 or 0, the form every model in this chapter needs. Only about 11% said yes.
bank <- read.csv("data/bank_marketing.csv", stringsAsFactors = TRUE)   # text columns become categories (factors)
bank$yes <- as.integer(bank$y == "yes")    # "yes"/"no" -> 1/0
bank$poutcome <- relevel(bank$poutcome, ref = "nonexistent")   # baseline = never contacted before
src <- "UCI Bank Marketing (Moro, Cortez & Rita 2014), CC BY 4.0"   # credit line for charts
mean(bank$yes)                             # mean of a 0/1 column = share who said yes

#| **Hold out a test set, stratified by outcome.** The file has no dates and its rows are in random order (UCI drew this 10% sample at random), so a time split is impossible. Instead we keep 30% of the *yes* clients and 30% of the *no* clients aside: `pos` counts each client's position within its own class, and positions 0, 1, 2 of every 10 go to the test set. This gives the same stratified split in R and Python. In your own projects use `set.seed()` and `sample()`.
# ave(..., FUN = seq_along) numbers rows 1, 2, 3, ... separately within "yes" and "no"; minus 1 starts at 0
pos <- ave(seq_len(nrow(bank)), bank$y, FUN = seq_along) - 1
is_test <- pos %% 10 < 3                   # %% = remainder: positions 0, 1, 2 of every 10 -> test
train <- bank[!is_test, ]                  # [rows, ] keeps all columns; ! means "not"
test  <- bank[is_test, ]
c(train = nrow(train), test = nrow(test), yes_train = sum(train$yes), yes_test = sum(test$yes))

#| **Three models, same five pre-call facts.** Age, phone type (`contact`), number of calls to the client in this campaign, counting the last one (`campaign`), the outcome of the previous campaign (`poutcome`) and the 3-month Euribor interest rate on the day of the call. `lm()` is the **linear probability model** (LPM); `glm(..., family = binomial)` fits a **logit**; `binomial(link = "probit")` fits a **probit**. All three are fitted on the training clients only.
f <- yes ~ age + contact + campaign + poutcome + euribor3m   # one formula shared by all three models
lpm    <- lm(f, data = train)                                # straight line (OLS) on a 0/1 target
logit  <- glm(f, family = binomial, data = train)            # logistic S-curve
probit <- glm(f, family = binomial(link = "probit"), data = train)   # normal-distribution S-curve

#| **Count the impossible predictions.** A probability must lie between 0 and 1. The straight line does not know that: look at how many training clients get a *negative* probability of saying yes. The logit and probit can never leave the interval, by construction.
p_lpm <- fitted(lpm); p_logit <- fitted(logit); p_probit <- fitted(probit)   # predicted probabilities, training clients
data.frame(model = c("LPM", "Logit", "Probit"),
           below_0 = c(sum(p_lpm < 0), sum(p_logit < 0), sum(p_probit < 0)),   # count of impossible values < 0
           above_1 = c(sum(p_lpm > 1), sum(p_logit > 1), sum(p_probit > 1)),   # count of impossible values > 1
           min = c(min(p_lpm), min(p_logit), min(p_probit)),
           max = c(max(p_lpm), max(p_logit), max(p_probit)))

#| **See it.** Each dot is one client: the logit's probability across, the LPM's up. Dots below the zero line are impossible forecasts. The two models agree in the middle; they part ways at the extremes, where the straight line overshoots.
viz_scatter(p_logit, p_lpm, fit = FALSE, xlab = "Logit probability", ylab = "LPM probability",   # fit = FALSE: no fitted line
            title = "The straight line predicts negative probabilities for some clients",
            source = src)

#| **But do they rank clients differently?** Here is a twist. The share of correctly ordered (yes, no) pairs, the AUC you will meet later in the chapter, is almost identical for all three on the **test** clients. The LPM's problem is not *who* it ranks first; it is that its numbers are not usable as probabilities.
# helper: AUC from ranks = share of (yes, no) pairs where the yes gets the higher score
auc <- function(p, y) { r <- rank(p); n1 <- sum(y); n0 <- length(y) - n1
  (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0) }
c(LPM = auc(predict(lpm, test), test$yes),   # test-set AUC of each model
  Logit = auc(predict(logit, test, type = "response"), test$yes),   # type = "response": probabilities
  Probit = auc(predict(probit, test, type = "response"), test$yes))
