# The tuned model from Lab 12.2 (the feature table is already built for you)
fit = xgb.train({"eta": 0.1, "max_depth": 2, "tree_method": "exact", "nthread": 1},
                xgb.DMatrix(train[features], label=train["growth"]), num_boost_round=38)
nov = test.loc[["2025-11-01"]]                 # the month to explain
dnov = xgb.DMatrix(nov[features])

# 1. Ask XGBoost for the SHAP values of November 2025
S = pd.Series(fit.predict(dnov, pred_contribs=True)[0], index=features + ["base"])

# 2. Rebuild the dollar forecast from the SHAP values alone:
#    last month's sales x (1 + (base value + all contributions) / 100)
forecast_from_shap = nov["lag1"].iloc[0] * (1 + S.sum() / 100)

# 3. Which feature pulled November's forecast DOWN the most?
biggest_drag = S[features].idxmin()
print(round(forecast_from_shap / 1000, 2), round(nov["sales"].iloc[0] / 1000, 2), biggest_drag)
