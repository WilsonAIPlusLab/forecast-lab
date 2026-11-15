#| **Stack 14 retail and food-service categories into one long table** (Census, NSA, $ millions). `make_features()` from the hidden setup builds the same seven features for each, and `cat` records the category as a number from 1 to 14 (trees split it into ranges; two splits isolate any one category). Because the target is growth in %, big and small categories fit in one model.
cats = {"Motor vehicles": "441", "Furniture": "442", "Electronics": "443", "Building materials": "444",
        "Food & beverage stores": "445", "Health & personal care": "446", "Gas stations": "447",
        "Clothing": "448", "Sporting goods & hobby": "451", "General merchandise": "452",
        "Misc. stores": "453", "Nonstore": "454", "E-commerce": "4541", "Food services & bars": "722"}
parts = []
for i, (name, code) in enumerate(cats.items(), start=1):
    p = make_features(fred(f"MRTSSM{code}USN")); p["cat"] = i; p["name"] = name; parts.append(p)
panel = pd.concat(parts)
print(panel.groupby("name").size().head(3))

#| **Choose how much history each model gets.** `years = 3` trains on 2019–2021 and validates on 2022: 36 rows per category. Change it to 29 later.
years = 3
fit_rows = panel[(panel.index >= f"{2022 - years}-01-01") & (panel.index <= "2021-12-01")]
val_rows = panel[panel.index.year == 2022]
test_rows = panel[panel.index >= "2023-01-01"].copy()

#| **One helper trains a model the honest way**: early stopping on 2022, then a refit on fit + validation rows.
params = {"eta": 0.1, "max_depth": 3, "tree_method": "exact", "nthread": 1}
def boost_es(a, b, cols):
    M = lambda z: xgb.DMatrix(z[cols], label=z["growth"])
    m = xgb.train(params, M(a), num_boost_round=500, evals=[(M(b), "valid")], early_stopping_rounds=30, verbose_eval=False)
    return xgb.train(params, M(pd.concat([a, b])), num_boost_round=m.best_iteration + 1)

#| **Global vs local**: one model for all 14 categories (with `cat` as a feature) against 14 separate models.
glob = boost_es(fit_rows, val_rows, features + ["cat"])
test_rows["g_global"] = glob.predict(xgb.DMatrix(test_rows[features + ["cat"]]))
test_rows["g_local"] = np.nan
for i in range(1, len(cats) + 1):
    loc = boost_es(fit_rows[fit_rows["cat"] == i], val_rows[val_rows["cat"] == i], features)
    rows = test_rows["cat"] == i
    test_rows.loc[rows, "g_local"] = loc.predict(xgb.DMatrix(test_rows.loc[rows, features]))

#| **Score each category**: MAPE of the dollar forecasts over the test months.
for k in ["local", "global"]:
    test_rows[k] = 100 * (test_rows["sales"] - test_rows["lag1"] * (1 + test_rows[f"g_{k}"] / 100)).abs() / test_rows["sales"]
res = test_rows.groupby("name")[["local", "global"]].mean().rename(columns={"local": "Local", "global": "Global"})
res["Gain from global (pts)"] = res["Local"] - res["Global"]
res["Winner"] = np.where(res["Global"] < res["Local"], "Global", "Local")
res = res.sort_values("Gain from global (pts)", ascending=False)
wins = int((res["Winner"] == "Global").sum())
print({"global_wins": wins, "avg_local": round(float(res["Local"].mean()), 4), "avg_global": round(float(res["Global"].mean()), 4)})

#| **The verdict.** With three years of history, the shared model wins 9 of 14 categories and cuts the average MAPE from about 5.4% to 4.1%. Set `years = 29` and run again: with three decades of data each, the average gap disappears (local 2.90%, global 3.00%).
viz_kpi(**{"Average MAPE, local models": f"{res['Local'].mean():.2f}%", "Average MAPE, global model": f"{res['Global'].mean():.2f}%",
           "Categories where global wins": f"{wins} of 14"})
viz_table(res.rename_axis("Category"), digits=2, title=f"With {years} years of history, the global model wins {wins} of 14 categories")
