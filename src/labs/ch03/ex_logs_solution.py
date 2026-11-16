online = fred("MRTSSM4541USS", start=2015)    # U.S. e-commerce sales, $ millions, seasonally adjusted
train = online[:"2022-12"]                    # training set: through December 2022
test = online["2023-01":]                     # test set: January 2023 onward
h = len(test)                                 # number of test months

def drift(y, h):                              # straight line from the first to the last value, extended h steps
    slope = (y.iloc[-1] - y.iloc[0]) / (len(y) - 1)
    return pd.Series(y.iloc[-1] + slope * np.arange(1, h + 1), index=test.index)

f_level = drift(train, h)                     # drift on levels: same $ change every month
f_log = drift(np.log(train), h)               # drift on logs: same % growth every month (in log units)
f_back = np.exp(f_log)                        # np.exp() undoes np.log(): back to $ millions

# Score BOTH forecasts in the original units, $ millions
mae_level = (test - f_level).abs().mean()
mae_log = (test - f_back).abs().mean()        # compare actual $ with back-transformed $
print({"level": round(mae_level), "log": round(mae_log)})   # about 1,958 vs 13,397: the straight line wins
