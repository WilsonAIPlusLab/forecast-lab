#| **Same data as the first lab**, plus the chip-shortage dummy.
import statsmodels.formula.api as smf
d = pd.concat({"veh": fred("TOTALSA"), "gas": fred("GASREGW", to="month"),
               "un": fred("UNRATE"), "mr": fred("MORTGAGE30US", to="month")}, axis=1, sort=True)
d = d["1993-01":].dropna(subset=["veh", "gas", "mr"])
d["chip"] = d.index.year.isin([2021, 2022]).astype(int)

#| **Stand at the end of 2023**: fit on data through December 2023 only.
train, test = d[:"2023-12"].dropna(), d["2024-01":]
fit = smf.ols("veh ~ gas + un + mr + chip", data=train).fit()

#| **Ex-post**: plug in the drivers' actual future values (impossible in real time). **Ex-ante**: hold each driver at its December 2023 value, the simplest honest driver forecast.
f_post = fit.predict(test)
last = train.iloc[-1]
xante = pd.DataFrame({"gas": last.gas, "un": last.un, "mr": last.mr, "chip": 0}, index=test.index)
f_ante = fit.predict(xante)
f_naive = pd.Series(train.veh.iloc[-1], index=test.index)
viz_compare(history=train.veh["2019":], actual=test.veh, **{"Ex-post (true drivers)": f_post,
            "Ex-ante (drivers held flat)": f_ante, "Naive": f_naive},
            title="Knowing the drivers' true future did not make the forecast better")

#| **Score all three** on the test period.
ok = f_post.notna()
def sc(f):
    e = (test.veh - f)[ok]
    return {"ME": e.mean(), "MAE": e.abs().mean(), "RMSE": np.sqrt((e**2).mean())}
scores = pd.DataFrame({"Ex-post (true drivers)": sc(f_post), "Ex-ante (drivers held flat)": sc(f_ante), "Naive": sc(f_naive)}).T
print(scores.round(3))
viz_table(scores, highlight=["MAE", "RMSE"], digits=2, title="Vehicle sales, test period 2024 onward (millions, SAAR)")
