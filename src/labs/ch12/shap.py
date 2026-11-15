#| **Refit the tuned model from Lab 12.2** (learning rate 0.1, depth-2 trees, 38 rounds). The hidden setup rebuilt `train` (1993–2022) and `test` (2023 onward).
params = {"eta": 0.1, "max_depth": 2, "tree_method": "exact", "nthread": 1}
fit = xgb.train(params, xgb.DMatrix(train[features], label=train["growth"]), num_boost_round=38)
dtest = xgb.DMatrix(test[features])
pred = fit.predict(dtest)

#| **Ask for SHAP values** with `pred_contribs=True`. You get one column per feature plus a last column, the **base value** (the model's average prediction). XGBoost computes these exactly with the TreeSHAP algorithm, so you do not need the `shap` package.
S = pd.DataFrame(fit.predict(dtest, pred_contribs=True), index=test.index, columns=features + ["base"])
print(S.tail(3).round(2))

#| **Check additivity**: base value + contributions = prediction, for every month.
print("Additive:", np.allclose(S.sum(axis=1), pred, atol=1e-5))

#| **Translate into dollars**: a contribution of *c* points of growth is worth *last month × c/100*. Divide by 1,000 for billions.
usd = S.mul(test["lag1"] / 100 / 1000, axis=0)
print(usd.loc["2025-12-01"].round(1))

#| **Draw the waterfall for December 2025**, from November's sales to the forecast. `viz_custom("waterfall", ...)` is a chart type this chapter adds to the site.
nice = {"month": "Calendar month", "growth_ly": "Same month last year's growth", "growth_lm": "Last month's growth",
        "yoy_lm": "Last month's 12-month growth", "weekend": "Weekend days", "sent_lm": "Consumer sentiment (last month)",
        "unrate_lm": "Unemployment rate (last month)"}
def waterfall(row, contrib_usd, growth_pred, title):
    v = contrib_usd[features]; o = v.abs().sort_values(ascending=False).index
    fc = row["lag1"] * (1 + growth_pred / 100) / 1000
    actual = "not yet known" if pd.isna(row["sales"]) else f"${row['sales'] / 1000:.1f}bn"
    viz_custom("waterfall", title=title, unit="$bn",
               subtitle=f"Starts from last month's sales (${row['lag1'] / 1000:.1f}bn) and ends at the forecast (${fc:.1f}bn). Actual: {actual}.",
               start=row["lag1"] / 1000, start_label="Last month's sales", base=float(contrib_usd["base"]),
               labels=[nice[f] for f in o], values=[float(v[f]) for f in o],
               feature_values=[None if pd.isna(row[f]) else float(row[f]) for f in o], total_label="Forecast")
i = test.index.get_loc(pd.Timestamp("2025-12-01"))
waterfall(test.iloc[i], usd.iloc[i], pred[i], "December 2025: last year's December jump does most of the lifting")

#| **Global importance**: the average absolute SHAP value per feature over the 45 test months, in dollars.
imp = usd[features].abs().mean().rename(nice)
viz_bars(imp, xlab="Mean |SHAP|, $ billions", title="Seasonal features move the forecast most; macro drivers barely register",
         subtitle="Average absolute SHAP value per feature, one-month-ahead forecasts, Jan 2023 to Sep 2026")

#| **Next month's forecast, explained.** Refit on everything through September 2026 and explain October 2026.
full = d.dropna(subset=["growth"])
fit_all = xgb.train(params, xgb.DMatrix(full[features], label=full["growth"]), num_boost_round=38)
nxt = make_features(retail, extra_month=True).iloc[[-1]]
dnext = xgb.DMatrix(nxt[features])
contrib = pd.Series(fit_all.predict(dnext, pred_contribs=True)[0], index=features + ["base"]) * nxt["lag1"].iloc[0] / 100 / 1000
waterfall(nxt.iloc[0], contrib, fit_all.predict(dnext)[0], "October 2026: the forecast, and why")
