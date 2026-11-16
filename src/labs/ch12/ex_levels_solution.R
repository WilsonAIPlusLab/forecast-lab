# Your manager: "Why predict growth? Just predict sales in dollars. It's simpler."
# Test the idea: same tuned settings, but the target is the sales LEVEL in $ billions.
d$sales_ly <- lag_by(d$sales, 12)                        # sales in the same month last year, $ millions
lev <- c("month", "lag1", "sales_ly", "weekend", "sent_lm", "unrate_lm")   # level features: last month, last year
tr <- d[d$date <= as.Date("2022-12-01"), ]               # training months, 1993-2022
te <- d[d$date >= as.Date("2023-01-01"), ]               # test months, Jan 2023 onward

# 1. Train on the level of sales. 143 trees were chosen by early stopping on 2022, as in Lab 12.1.
fit_lev <- xgb.train(params = list(eta = 0.1, max_depth = 2, tree_method = "exact", nthread = 1),
                     data = xgb.DMatrix(as.matrix(tr[, lev]), label = tr$sales / 1000), nrounds = 143)   # target: sales level, $ billions
pred_lev <- predict(fit_lev, xgb.DMatrix(as.matrix(te[, lev])))   # level forecasts, $ billions

# 2. Can a tree forecast a month bigger than anything it has seen?
ceiling_bn <- max(tr$sales) / 1000                     # the record month in 1993-2022
c(highest_training_month = ceiling_bn, highest_forecast = max(pred_lev), highest_actual = max(te$sales) / 1000)

# 3. Score it like Lab 12.2 (the growth model's MAE was $10.35bn)
mae_lev <- mean(abs(te$sales / 1000 - pred_lev))         # mean absolute error, $ billions
mae_lev
