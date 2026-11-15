#| **The product list**: 14 U.S. retail categories ($ millions, NSA). E-commerce (4541) is part of nonstore retailers (454).
import warnings; warnings.filterwarnings("ignore")
from statsmodels.tsa.exponential_smoothing.ets import ETSModel
cats = {"441": "Motor vehicles & parts", "442": "Furniture", "443": "Electronics & appliances",
        "444": "Building materials", "445": "Food & beverage stores", "446": "Health & personal care",
        "447": "Gasoline stations", "448": "Clothing", "451": "Sporting goods & hobby",
        "452": "General merchandise", "453": "Misc. store retailers", "454": "Nonstore retailers",
        "4541": "E-commerce", "722": "Food services & drinking"}

#| **One recipe for one series.** Like R's `ets(model = "ZZM")`, we fix multiplicative seasonality and let AICc choose the trend: none (M,N,M), linear (M,A,M) or damped (M,Ad,M). Then we backtest on the 12 months to Aug 2026 and re-run the chosen model with the *same parameters* through all the data (`smooth()`), to forecast the next 12 months. statsmodels sometimes picks a different trend type than R on borderline categories, so the middle of the report can reshuffle; the worst three categories are the same.
TRENDS = {"ETS(M,N,M)": (None, False), "ETS(M,A,M)": ("add", False), "ETS(M,Ad,M)": ("add", True)}
def ets_zzm(y):
    fits = {k: ETSModel(y, error="mul", trend=t, damped_trend=d, seasonal="mul", seasonal_periods=12).fit(disp=False)
            for k, (t, d) in TRENDS.items()}
    name = min(fits, key=lambda k: fits[k].aicc)
    return name, fits[name]

def run_one(code):
    y = fred(f"MRTSSM{code}USN", start=2015)
    train, test = y[:"2025-08"], y["2025-09":]
    name, fit = ets_zzm(train)
    e = test.values - fit.forecast(12).values
    scale = (train - train.shift(12)).abs().mean()
    t, d = TRENDS[name]
    full = ETSModel(y, error="mul", trend=t, damped_trend=d, seasonal="mul", seasonal_periods=12).smooth(fit.params)
    fc = full.get_prediction(start=len(y), end=len(y) + 11).summary_frame(alpha=0.20)
    return dict(code=code, name=cats[code], model=name, MAPE=100 * np.mean(np.abs(e / test.values)),
                MASE=np.mean(np.abs(e)) / scale, y=y, fc=fc)

#| **The Monday-morning loop** over every category.
results = [run_one(c) for c in cats]
len(results)

#| **Exception report**, worst first, with a traffic-light status.
report = pd.DataFrame([{k: r[k] for k in ["name", "model", "MAPE", "MASE"]} for r in results])
report.columns = ["Category", "Model", "MAPE", "MASE"]
report["Status"] = np.where(report.MASE > 1, "Review", np.where(report.MASE > 0.8, "Watch", "OK"))
report = report.sort_values("MASE", ascending=False).reset_index(drop=True)
print(report.round(2))
viz_table(report, digits=2, title="Exception report: categories sorted by backtest MASE (worst first)")

#| **Bars and small multiples**, the same charts as the R tab.
viz_bars(report.MASE.values, labels=report.Category.values, xlab="backtest MASE (12 months to Aug 2026)",
         highlight=list(report.Category[report.Status == "Review"]),
         title="Categories above 1 need a human look before the forecast ships")
dates = lambda idx: [d.strftime("%Y-%m-%d") for d in idx]
viz_custom("ch05-multiples", title="Next 12 months, every category",
           source="FRED, Federal Reserve Bank of St. Louis (MRTSSM441USN … MRTSSM722USN)",
           panels=[dict(name=r["name"], model=r["model"], mase=float(r["MASE"]),
                        date=dates(r["y"]["2022":].index), value=r["y"]["2022":].tolist(),
                        fdate=dates(pd.date_range(r["y"].index[-1] + pd.offsets.MonthBegin(), periods=12, freq="MS")),
                        mean=r["fc"]["mean"].tolist(), lo=r["fc"]["pi_lower"].tolist(), hi=r["fc"]["pi_upper"].tolist())
                   for r in results])
