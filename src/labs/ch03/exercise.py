online = fred("MRTSSM4541USS", start=2015)    # U.S. e-commerce sales, $ millions, seasonally adjusted
train = online[:"2022-12"]                    # training set: everything up to December 2022
test = online["2023-01":]                     # test set: January 2023 onward

# 1. Forecast the test period with the SEASONAL NAIVE method: repeat the last 12 training months
last_year = train.iloc[______:].values        # blank: the position that starts the last 12 rows
f_sn = pd.Series([last_year[i % 12] for i in range(len(test))], index=test.index)   # i % 12 cycles 0..11

# 2. Compute the test-set MAE by hand: the mean of the absolute errors
mae = (______ - f_sn).abs().mean()            # blank: what actually happened (error = actual - forecast)
print(mae)
