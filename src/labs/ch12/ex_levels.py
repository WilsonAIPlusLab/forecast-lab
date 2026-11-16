# Your manager: "Why predict growth? Just predict sales in dollars. It's simpler."
# Test the idea: same tuned settings, but the target is the sales LEVEL in $ billions.
d["sales_ly"] = d["sales"].shift(12)                     # sales in the same month last year, $ millions
lev = ["month", "lag1", "sales_ly", "weekend", "sent_lm", "unrate_lm"]   # level features: last month, last year
tr, te = d[:"2022-12"], d["2023-01":]                    # training months 1993-2022; test months Jan 2023 onward

# 1. Train on the level of sales. 143 trees were chosen by early stopping on 2022, as in Lab 12.1.
# blank: the target, sales in $ billions (the column is in $ millions)
fit_lev = xgb.train({"eta": 0.1, "max_depth": 2, "tree_method": "exact", "nthread": 1},
                    xgb.DMatrix(tr[lev], label=______), num_boost_round=143)
pred_lev = fit_lev.predict(xgb.DMatrix(te[lev]))         # level forecasts, $ billions

# 2. Can a tree forecast a month bigger than anything it has seen?
# blank: the highest monthly sales in the TRAINING data, in $ billions
ceiling_bn = ______
print({"highest_training_month": round(float(ceiling_bn), 2), "highest_forecast": round(float(pred_lev.max()), 2),
       "highest_actual": round(float(te["sales"].max()) / 1000, 2)})

# 3. Score it like Lab 12.2 (the growth model's MAE was $10.35bn)
mae_lev = np.mean(np.abs(te["sales"] / 1000 - pred_lev))   # mean absolute error, $ billions
print(round(float(mae_lev), 2))
