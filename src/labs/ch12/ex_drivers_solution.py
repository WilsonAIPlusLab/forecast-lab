# Your manager: "Sales jumped in March 2026. Why did our model see it coming? Give me three reasons, in dollars."
# The tuned model from Lab 12.2 (the feature table is already built for you)
fit = xgb.train({"eta": 0.1, "max_depth": 2, "tree_method": "exact", "nthread": 1},   # tuned settings
                xgb.DMatrix(train[features], label=train["growth"]), num_boost_round=38)   # 38 trees
mar = test.loc[["2026-03-01"]]                   # the month to explain (one row)
S = pd.Series(fit.predict(xgb.DMatrix(mar[features]), pred_contribs=True)[0], index=features + ["base"])   # % points
lag1 = mar["lag1"].iloc[0]                       # February's sales, $ millions

# 1. Convert the seven feature contributions from % points of growth into $ billions.
#    1 point of growth is worth 1% of last month's sales; lag1 is in $ millions.
usd = S[features] * lag1 / 100 / 1000          # points -> % of last month -> $ millions -> $ billions

# 2. Keep the three features that moved the forecast most, up OR down.
top3 = usd[usd.abs().sort_values(ascending=False).index[:3]]   # sort by size, ignoring the sign

# 3. The three sentences for your manager
fc = lag1 * (1 + S.sum() / 100) / 1000           # the forecast, $ billions (base + all pushes)
print(f"We expected March 2026 sales of ${fc:.1f} billion, up from ${lag1 / 1000:.1f} billion in February.")
print("The biggest drivers: " + ", ".join(f"{k} ({v:+.1f} bn)" for k, v in top3.items()) + ".")
print(f"Actual sales came in at ${mar['sales'].iloc[0] / 1000:.1f} billion; these are the model's reasons, not proof of cause.")
