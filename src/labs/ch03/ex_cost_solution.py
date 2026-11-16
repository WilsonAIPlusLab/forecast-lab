retail = fred("RSXFSN", start=2010)           # monthly U.S. retail sales, $ millions, NSA
train = retail[:"2022-12"]                    # training set: through December 2022
test = retail["2023-01":]                     # test set: January 2023 onward
# seasonal naive: repeat the last 12 training months (i % 12 cycles 0..11)
f_sn = pd.Series([train.iloc[-12 + (i % 12)] for i in range(len(test))], index=test.index)
f_nv = pd.Series(train.iloc[-1], index=test.index)   # naive: last training value, repeated

# Business cost per month. Each $1 million of UNDER-forecast (empty shelves, lost sales)
# costs 4 cost units; each $1 million of OVER-forecast (leftover stock) costs 1 unit.
def biz_cost(actual, fc):
    e = actual - fc                           # error: + means the forecast was too low
    return np.where(e > 0, 4 * e, -e).mean()  # under: 4 units per $1M; over: -e is the positive size of the miss

costs = {"Seasonal naive": biz_cost(test, f_sn), "Naive": biz_cost(test, f_nv)}
maes = {"Seasonal naive": (test - f_sn).abs().mean(), "Naive": (test - f_nv).abs().mean()}
print(pd.DataFrame({"MAE": maes, "Cost": costs}).T.round(0))   # MAE picks seasonal naive; the 4-to-1 cost picks naive
