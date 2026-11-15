# Hidden setup shared by the bank-marketing labs: load, code the target, split (same as the first lab).
bank <- read.csv("data/bank_marketing.csv", stringsAsFactors = TRUE)
bank$yes <- as.integer(bank$y == "yes")
bank$poutcome <- relevel(bank$poutcome, ref = "nonexistent")
pos <- ave(seq_len(nrow(bank)), bank$y, FUN = seq_along) - 1
is_test <- pos %% 10 < 3
train <- bank[!is_test, ]
test  <- bank[is_test, ]
src <- "UCI Bank Marketing (Moro, Cortez & Rita 2014), CC BY 4.0"
