#| **Same data as the first lab**, plus the chip-shortage dummy.
import statsmodels.formula.api as smf      # R-style regression formulas
# one column per series: vehicle sales (mn, SAAR), gas ($/gal), unemployment (%), mortgage rate (%)
d = pd.concat({"veh": fred("TOTALSA"), "gas": fred("GASREGW", to="month"),
               "un": fred("UNRATE"), "mr": fred("MORTGAGE30US", to="month")}, axis=1, sort=True)
d = d["1993-01":].dropna(subset=["veh", "gas", "mr"])   # from Jan 1993; drop months missing sales, gas or rate
d["chip"] = d.index.year.isin([2021, 2022]).astype(int)   # chip-shortage dummy: 1 in 2021-2022, else 0

#| **Stand at the end of 2023**: fit on data through December 2023 only.
train, test = d[:"2023-12"].dropna(), d["2024-01":]   # training set through Dec 2023; test set from Jan 2024
fit = smf.ols("veh ~ gas + un + mr + chip", data=train).fit()   # regression fitted on training data only

#| **Ex-post**: plug in the drivers' actual future values (impossible in real time). **Ex-ante**: hold each driver at its December 2023 value, the simplest honest driver forecast.
f_post = fit.predict(test)                 # ex-post: uses the true future driver values
last = train.iloc[-1]                      # .iloc[-1] = last training row (December 2023)
# ex-ante drivers: December 2023 values repeated for every test month
xante = pd.DataFrame({"gas": last.gas, "un": last.un, "mr": last.mr, "chip": 0}, index=test.index)
f_ante = fit.predict(xante)
f_naive = pd.Series(train.veh.iloc[-1], index=test.index)   # naive: last observed sales, repeated
# 2019+ history and real test data; **{...} passes each entry as a named forecast
viz_compare(history=train.veh["2019":], actual=test.veh, **{"Ex-post (true drivers)": f_post,
            "Ex-ante (drivers held flat)": f_ante, "Naive": f_naive},
            title="Knowing the drivers' true future did not make the forecast better")

#| **Score all three** on the test period.
ok = f_post.notna()                        # score only months with an ex-post forecast
def sc(f):                                 # helper: mean error, mean absolute error, root mean squared error
    e = (test.veh - f)[ok]                 # errors = actual - forecast
    return {"ME": e.mean(), "MAE": e.abs().mean(), "RMSE": np.sqrt((e**2).mean())}
# one row per method (.T flips columns into rows)
scores = pd.DataFrame({"Ex-post (true drivers)": sc(f_post), "Ex-ante (drivers held flat)": sc(f_ante), "Naive": sc(f_naive)}).T
print(scores.round(3))                     # lower MAE and RMSE are better
viz_table(scores, highlight=["MAE", "RMSE"], digits=2, title="Vehicle sales, test period 2024 onward (millions, SAAR)")
