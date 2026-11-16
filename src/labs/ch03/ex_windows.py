unrate = fred("UNRATE", start=2005)           # unemployment rate, %, seasonally adjusted

# Score naive and drift on ONE test year: train through December of `yr`, test on the next 12 months
def score_year(yr):
    train = unrate[:f"{yr}-12"]               # everything up to December of yr
    nxt = ______                              # blank: the test year, right after the training data ends
    test = unrate[f"{nxt}-01":f"{nxt}-12"].values   # January to December of the test year
    naive = np.repeat(train.iloc[-1], 12)     # naive: last value, repeated 12 times
    slope = (train.iloc[-1] - train.iloc[0]) / (len(train) - 1)   # drift: average change per month
    drift = train.iloc[-1] + slope * np.arange(1, 13)              # straight line from first to last point
    return {"naive": np.abs(test - naive).mean(), "drift": np.abs(test - drift).mean()}   # MAEs, pct. points

# one row per test year (2011 to 2019); .T flips columns into rows
res = pd.DataFrame({yr + 1: score_year(yr) for yr in range(2010, 2019)}).T
print(res.round(2))
wins_naive = int((res["naive"] ______ res["drift"]).sum())   # blank: True when naive's MAE is smaller (True counts as 1)
print(wins_naive)                             # number of test years naive wins, out of 9
print(res.mean())                             # average MAE over all 9 test years
