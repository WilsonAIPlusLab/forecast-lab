# The tuned model from Lab 13.2 (the feature table is already built for you)
fit = xgb.train({"eta": 0.1, "max_depth": 2, "tree_method": "exact", "nthread": 1},   # tuned settings
                xgb.DMatrix(train[features], label=train["growth"]), num_boost_round=38)   # 38 trees
nov = test.loc[["2025-11-01"]]                 # the month to explain
dnov = xgb.DMatrix(nov[features])              # its features, in XGBoost's data format

# 1. Ask XGBoost for the SHAP values of November 2025
# blank: the Python boolean that switches on per-feature contributions
S = pd.Series(fit.predict(dnov, pred_contribs=______)[0], index=features + ["base"])

# 2. Rebuild the dollar forecast from the SHAP values alone:
#    last month's sales x (1 + (base value + all contributions) / 100)
# blank: one number, the total of every value in S
forecast_from_shap = nov["lag1"].iloc[0] * (1 + ______ / 100)

# 3. Which feature pulled November's forecast DOWN the most?
biggest_drag = S[features].idxmin()            # feature with the most negative contribution
print(round(forecast_from_shap / 1000, 2), round(nov["sales"].iloc[0] / 1000, 2), biggest_drag)   # forecast, actual ($bn), drag
