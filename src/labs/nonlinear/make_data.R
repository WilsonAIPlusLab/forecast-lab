# Generates src/components/nonlinear/nldata.json for the chapter's explorables.
# Run from site/:  Rscript src/labs/nonlinear/make_data.R
# Every model here is the same as in the chapter's labs (same split, same formulas).
library(jsonlite)
setwd("public")
r4 <- function(x, d = 4) round(x, d)

# ---- bank: chapter model on the training clients, test-set predictions with/without duration
bank <- read.csv("data/bank_marketing.csv", stringsAsFactors = TRUE)
bank$yes <- as.integer(bank$y == "yes"); bank$poutcome <- relevel(bank$poutcome, ref = "nonexistent")
pos <- ave(seq_len(nrow(bank)), bank$y, FUN = seq_along) - 1; is_test <- pos %% 10 < 3
train <- bank[!is_test, ]; test <- bank[is_test, ]
f <- yes ~ age + contact + campaign + poutcome + euribor3m
logit <- glm(f, family = binomial, data = train)
leaky <- glm(update(f, . ~ . + duration), family = binomial, data = train)
p <- predict(logit, test, type = "response"); pd <- predict(leaky, test, type = "response")
xbar <- colMeans(model.matrix(logit))

out <- list(
  bank = list(coef = as.list(r4(coef(logit), 6)), xbar = as.list(r4(xbar, 6)), base = mean(train$yes),
              test = list(p = r4(unname(p)), pd = r4(unname(pd)), y = test$yes))
)
write_json(out, "../src/components/nonlinear/nldata.json", auto_unbox = TRUE, digits = NA)
cat("wrote nldata.json\n")
