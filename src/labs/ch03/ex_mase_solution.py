# MASE by hand: the test-set MAE divided by the in-sample MAE of seasonal naive
def mase(train, test, fc):
    scale = (train - train.shift(12)).abs().mean()   # in-sample seasonal naive MAE; .shift(12) = value 12 months earlier
    return (test - fc).abs().mean() / scale   # test MAE / benchmark MAE: the units cancel

# Score the seasonal naive forecast of one series: train through 2022, test from 2023
def score(y):
    train = y[:"2022-12"]                     # training set
    test = y["2023-01":]                      # test set
    # seasonal naive: repeat the last 12 training months (i % 12 cycles 0..11)
    fc = pd.Series([train.iloc[-12 + (i % 12)] for i in range(len(test))], index=test.index)
    return mase(train, test, fc)

retail = fred("RSXFSN", start=2010)           # retail sales, $ millions, NSA
houses = fred("HOUSTNSA", start=2010)         # housing starts, thousands of units, NSA
result = {"retail": score(retail), "houses": score(houses)}   # one MASE per series
print(result)                                 # retail about 1.04, housing starts about 1.67
