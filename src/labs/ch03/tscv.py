#| **Pre-COVID retail sales**, 2010 to 2019.
retail = fred("RSXFSN", start=2010, end="2019-12-01")
y = retail.values

#| **Rolling-origin cross-validation by hand.** For each origin `o` we train on the first `o` values, `y[:o]`, and forecast 1 to 12 steps ahead. Like R's `tsCV()`, we start as soon as a method can run: seasonal naive needs 12 values, drift needs 2. So the numbers match the R tab.
H = 12
def snaive(tr, h): return np.array([tr[-12 + (i % 12)] for i in range(h)])
def drift(tr, h):  return tr[-1] + (tr[-1] - tr[0]) / (len(tr) - 1) * np.arange(1, h + 1)

def tscv(method, min_train):
    errs = np.full((len(y), H), np.nan)
    for o in range(min_train, len(y)):
        f = method(y[:o], H)
        for k in range(H):
            if o + k < len(y):
                errs[o, k] = y[o + k] - f[k]
    return errs

e_snaive, e_drift = tscv(snaive, 12), tscv(drift, 2)
e_snaive.shape

#| **MAE at each horizon**: average the absolute errors down each column, ignoring the empty (`NaN`) cells near the end of the data.
mae_snaive = np.nanmean(np.abs(e_snaive), axis=0)
mae_drift = np.nanmean(np.abs(e_drift), axis=0)
print(pd.DataFrame({"Seasonal naive": mae_snaive, "Drift": mae_drift}, index=range(1, 13)).round(0).T)

#| **Error by horizon**, the professional way to report accuracy.
viz_lines(range(1, 13), **{"Seasonal naive": mae_snaive}, Drift=mae_drift, xlab="months ahead",
          ylab="MAE ($ millions)", zero=True, title="Seasonal naive beats drift at every horizon")
