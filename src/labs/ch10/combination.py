#| **One series first.** Train on total retail sales 2010–2017 (`RSXFSN`, $ millions, NSA), forecast 2018–2019 with three methods, and average them. statsmodels has no automatic ETS, so we use ETS(M,A,M) throughout; R's `ets(model = "ZZM")` sometimes picks a different trend or error type, so a few numbers differ from the R tab.
import warnings; warnings.filterwarnings("ignore")
from statsmodels.tsa.exponential_smoothing.ets import ETSModel
from statsmodels.tsa.statespace.sarimax import SARIMAX

def three_forecasts(tr, h=24):
    e = ETSModel(tr, error="mul", trend="add", seasonal="mul", seasonal_periods=12).fit(disp=False).forecast(h)
    fa = SARIMAX(np.log(tr), order=(0, 1, 1), seasonal_order=(0, 1, 1, 12), concentrate_scale=True).fit(disp=False).get_forecast(h)
    a = np.exp(fa.predicted_mean + 0.5 * fa.se_mean ** 2)      # bias-adjusted back-transform, like R's biasadj = TRUE
    s = pd.Series([tr.iloc[-12 + (i % 12)] for i in range(h)], index=e.index)
    return e, a, s

retail = fred("RSXFSN", start=2010)
train, test = retail[:"2017-12"], retail["2018-01":"2019-12"]
f_ets, f_arima, f_snaive = three_forecasts(train)
f_combo = (f_ets + f_arima + f_snaive) / 3
viz_compare(history=train["2015":], actual=test, ETS=f_ets, ARIMA=f_arima, **{"Seasonal naive": f_snaive}, Combination=f_combo,
            title="Three forecasts and their average, 2018–2019")

#| **Score with MASE**: test MAE divided by the in-sample MAE of seasonal naive.
def mase(f, tr, te):
    return np.mean(np.abs(te.values - f.values)) / np.mean(np.abs(tr.diff(12).dropna()))
print({k: round(float(mase(f, train, test)), 3) for k, f in {"ETS": f_ets, "ARIMA": f_arima, "Seasonal naive": f_snaive, "Combination": f_combo}.items()})

#| **Eight series.** The same recipe on total retail and seven store categories (NSA, $ millions).
ids = {"Total retail": "RSXFSN", "Clothing": "MRTSSM448USN", "Sporting goods": "MRTSSM451USN", "Electronics": "MRTSSM443USN",
       "Building materials": "MRTSSM444USN", "General merchandise": "MRTSSM452USN", "Health & personal care": "MRTSSM446USN",
       "Furniture": "MRTSSM442USN"}
rows = {}
for name, sid in ids.items():
    y = fred(sid, start=2010)
    tr, te = y[:"2017-12"], y["2018-01":"2019-12"]
    e, a, s = three_forecasts(tr)
    rows[name] = {"ETS": mase(e, tr, te), "ARIMA": mase(a, tr, te), "Seasonal naive": mase(s, tr, te), "Combination": mase((e + a + s) / 3, tr, te)}
board = pd.DataFrame(rows).T
print(board.round(2))

#| **The scorecard**, one column per series, green = best in that column, last column = average MASE. In this Python version, statsmodels' ETS(M,A,M) happens to forecast these series better than R's ETS did, and it edges out the combination on average. The combination still never comes last. Results from one two-year test window are noisy; the robust pattern is the *insurance*, not a guaranteed win.
card = board.T
card["Average"] = board.mean()
viz_table(card, highlight=list(card.columns), digits=2, title="The simple average was never the worst, even where it was not the best")

#| **Wins and losses** across the eight series.
print(pd.DataFrame({"best": board.idxmin(axis=1).value_counts(), "worst": board.idxmax(axis=1).value_counts()}).reindex(board.columns).fillna(0).astype(int).T)
