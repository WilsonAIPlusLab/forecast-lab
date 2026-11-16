# Hidden setup shared by the Chapter 12 Python labs: builds the supervised feature table.
# (Lab 12.1 builds the same table step by step, with explanations.)
# Creates: retail, d (every month), train (1993-2022), test (2023 onward), features (7 predictor names), make_features().
import xgboost as xgb

def weekend_days(idx):                   # idx = first day of each month
    start = idx.values.astype("datetime64[D]")
    n_days = ((idx + pd.offsets.MonthBegin(1)).values.astype("datetime64[D]") - start).astype(int)
    dow = ((start[:, None] + np.arange(31)).astype("int64") + 3) % 7      # Monday = 0 ... Sunday = 6
    return ((dow >= 5) & (np.arange(31) < n_days[:, None])).sum(axis=1)

def monthly_lag(s, start):
    return s.reindex(pd.date_range(start, s.index[-1] + pd.offsets.MonthBegin(1), freq="MS")).shift(1)

def read_monthly(id):                   # raw file: the October 2025 hole in UNRATE stays a hole
    return pd.read_csv(f"data/{id}.csv", index_col=0, parse_dates=True, na_values=[".", ""]).iloc[:, 0]

_sent_lm = monthly_lag(read_monthly("UMCSENT"), "1950-01-01")
_unrate_lm = monthly_lag(read_monthly("UNRATE"), "1948-01-01")

def make_features(y, extra_month=False):
    y = y.copy()
    if extra_month:
        y.loc[y.index[-1] + pd.offsets.MonthBegin(1)] = np.nan
    d = pd.DataFrame({"sales": y})
    d["lag1"] = d["sales"].shift(1)
    d["growth"] = 100 * (d["sales"] / d["lag1"] - 1)
    d["month"] = d.index.month
    d["growth_ly"] = d["growth"].shift(12)
    d["growth_lm"] = d["growth"].shift(1)
    d["yoy_lm"] = 100 * (d["lag1"] / d["sales"].shift(13) - 1)
    d["weekend"] = weekend_days(d.index)
    d["sent_lm"] = _sent_lm.reindex(d.index)
    d["unrate_lm"] = _unrate_lm.reindex(d.index)
    return d.dropna(subset=["growth_ly", "yoy_lm"])

features = ["month", "growth_ly", "growth_lm", "yoy_lm", "weekend", "sent_lm", "unrate_lm"]
retail = fred("RSXFSN", start=1992)
d = make_features(retail)
train, test = d[:"2022-12"], d["2023-01":]
