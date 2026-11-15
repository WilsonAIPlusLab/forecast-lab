#| **Pre-COVID retail sales**, 2010 to 2019.
retail = fred("RSXFSN", start=2010, end="2019-12-01")   # monthly retail sales, $ millions, NSA, 2010-2019
y = retail.values                             # plain NumPy array of the values (no dates)

#| **Rolling-origin cross-validation by hand.** For each origin `o` we train on the first `o` values, `y[:o]`, and forecast 1 to 12 steps ahead. Like R's `tsCV()`, we start as soon as a method can run: seasonal naive needs 12 values, drift needs 2. So the numbers match the R tab.
H = 12                                        # forecast horizons 1 to 12 months
def snaive(tr, h): return np.array([tr[-12 + (i % 12)] for i in range(h)])   # same month one year earlier
def drift(tr, h):  return tr[-1] + (tr[-1] - tr[0]) / (len(tr) - 1) * np.arange(1, h + 1)   # line from first to last point

def tscv(method, min_train):                  # matrix of errors: one row per origin, one column per horizon
    errs = np.full((len(y), H), np.nan)       # start with all cells empty (NaN)
    for o in range(min_train, len(y)):        # each forecast origin
        f = method(y[:o], H)                  # train on the first o values, forecast H steps
        for k in range(H):
            if o + k < len(y):                # skip forecasts that run past the end of the data
                errs[o, k] = y[o + k] - f[k]  # error = actual - forecast, k+1 months ahead
    return errs

e_snaive, e_drift = tscv(snaive, 12), tscv(drift, 2)   # minimum training sizes: 12 and 2 values
e_snaive.shape                                # (rows, columns) = (origins, horizons)

#| **MAE at each horizon**: average the absolute errors down each column, ignoring the empty (`NaN`) cells near the end of the data.
mae_snaive = np.nanmean(np.abs(e_snaive), axis=0)   # axis=0 = average down each column
mae_drift = np.nanmean(np.abs(e_drift), axis=0)
print(pd.DataFrame({"Seasonal naive": mae_snaive, "Drift": mae_drift}, index=range(1, 13)).round(0).T)   # .T: one row per method

#| **Error by horizon**, the professional way to report accuracy.
viz_lines(range(1, 13), **{"Seasonal naive": mae_snaive}, Drift=mae_drift, xlab="months ahead",   # one line per method
          # zero=True starts the y-axis at 0
          ylab="MAE ($ millions)", zero=True, title="Seasonal naive beats drift at every horizon")
