#| **A real hierarchy**: total retail & food services = motor vehicles + everything else, and everything else = nine categories + **Other** (the remainder, so the tree adds up exactly). Seasonally adjusted, $ millions per month.
from statsmodels.tsa.exponential_smoothing.ets import ETSModel
import warnings; warnings.filterwarnings("ignore")
cats = {"Food_services": "RSFSDP", "Gas": "RSGASS", "Clothing": "RSCCAS", "Building": "RSDBS",
        "Health": "RSHPCS", "Nonstore": "RSNSR", "General": "RSGMS", "Furniture": "RSFHFS", "Electronics": "RSEAS"}
bottom = pd.DataFrame({k: fred(v, start=2015) for k, v in cats.items()})
ex_autos = fred("RSFSXMV", start=2015)
bottom["Other"] = ex_autos - bottom.sum(axis=1)
bottom.insert(0, "Motor_vehicles", fred("RSMVPD", start=2015))
all_ = pd.concat([fred("RSAFS", start=2015).rename("Total"), ex_autos.rename("Ex_autos"), bottom], axis=1)
print(all_.shape)

#| **The summing matrix S**: one row per node, one column per bottom series.
S = np.vstack([np.ones(11), np.r_[0, np.ones(10)], np.eye(11)])
print(S[:3].astype(int))

#| **Forecast all 13 series in a loop.** For each one we fit three additive-error ETS models (no trend, trend, damped trend) and keep the lowest AIC. R's `ets(model = "ZZN")` also tries multiplicative errors, so a few base forecasts differ slightly from the R lab.
h = 12
train, test = all_.iloc[:-h], all_.iloc[-h:]
def best_ets(y):
    fits = [ETSModel(y, error="add", trend=t, damped_trend=d).fit(disp=False)
            for t, d in [(None, False), ("add", False), ("add", True)]]
    return min(fits, key=lambda f: f.aic).forecast(h).values
base = pd.DataFrame({c: best_ets(train[c]) for c in all_.columns}, index=test.index)
print((base["Total"] - base[bottom.columns].sum(axis=1)).head(3).round(0))   # incoherence

#| **Bottom-up, top-down, and OLS/WLS reconciliation** in a few lines of matrix algebra.
bu = base[bottom.columns] @ S.T
share = (train[bottom.columns].tail(12).div(train["Total"].tail(12), axis=0)).mean()
td = np.outer(base["Total"], share) @ S.T
def reconcile(W):
    Wi = np.linalg.inv(W)
    return S @ np.linalg.inv(S.T @ Wi @ S) @ S.T @ Wi
ols = base.values @ reconcile(np.eye(13)).T
wls = base.values @ reconcile(np.diag(S.sum(axis=1))).T

#| **Score every method at every level** (MAPE, %, over the 12 test months).
def mape(f):
    return pd.Series(100 * (np.abs(test.values - np.asarray(f)) / test.values).mean(axis=0), index=all_.columns)
scores = pd.DataFrame({m: mape(f) for m, f in
                       {"Base": base, "Bottom-up": bu, "Top-down": td, "OLS": ols, "WLS": wls}.items()}).T
summary_tab = pd.DataFrame({"Total": scores["Total"], "Ex-autos": scores["Ex_autos"],
                            "Avg of 11 categories": scores[bottom.columns].mean(axis=1),
                            "Adds up?": ["No", "Yes", "Yes", "Yes", "Yes"]})
print(summary_tab.round(2))
viz_table(summary_tab, highlight=["Total", "Ex-autos", "Avg of 11 categories"], digits=2,
          title="Bottom-up gives the best total here; only Base is incoherent")
