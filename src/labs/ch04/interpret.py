#| **Same data as the drivers lab.** Monthly U.S. light vehicle sales (millions of units, seasonally adjusted annual rate), the gas price (\$ per gallon), the unemployment rate (%) and the 30-year mortgage rate (%), January 1993 to October 2026, plus the 2021–2022 chip-shortage dummy.
import statsmodels.formula.api as smf      # R-style formulas: smf.ols("y ~ x1 + x2", data)
# one column per series: vehicle sales (mn, SAAR), gas ($/gal), unemployment (%), 30-yr mortgage rate (%)
d = pd.concat({"veh": fred("TOTALSA"), "gas": fred("GASREGW", to="month"),
               "un": fred("UNRATE"), "mr": fred("MORTGAGE30US", to="month")}, axis=1, sort=True)
d = d["1993-01":].dropna()                 # keep Jan 1993 onward, drop months missing any series
d["chip"] = d.index.year.isin([2021, 2022]).astype(int)   # chip-shortage dummy: 1 in 2021-22, else 0

#| **One question, four functional forms.** Fit the same model four ways: sales in levels or logs, gas in levels or logs. Each gas coefficient has a *different meaning*. To compare them fairly, translate each into one business answer: *how many cars a year do we lose if gas goes from \$4 to \$5?* Today's sales (16.0 million) turn percentages into cars. The forms with gas in dollars say about −0.48 million; the forms with log(gas) say about −0.23, because logging gas assumes a dollar matters less when gas is already expensive. Report the range.
m_ll  = smf.ols("veh ~ gas + un + mr + chip", data=d).fit()                 # level-level
m_lgl = smf.ols("np.log(veh) ~ gas + un + mr + chip", data=d).fit()         # log-level
m_llg = smf.ols("veh ~ np.log(gas) + un + mr + chip", data=d).fit()         # level-log
m_lgg = smf.ols("np.log(veh) ~ np.log(gas) + un + mr + chip", data=d).fit() # log-log
s_now = d.veh.iloc[-1]                     # latest sales, millions (October 2026)
b = [m_ll.params["gas"], m_lgl.params["gas"], m_llg.params["np.log(gas)"], m_lgg.params["np.log(gas)"]]
effect = [b[0] * 1,                        # level-level: b units per $1
          s_now * (np.exp(b[1] * 1) - 1),  # log-level: exact % change exp(b) - 1, times sales
          b[2] * np.log(5 / 4),            # level-log: b times the change in log gas
          s_now * ((5 / 4) ** b[3] - 1)]   # log-log: exact % change (5/4)^b - 1, times sales
tab = pd.DataFrame({"Form": ["level-level", "log-level", "level-log", "log-log"],
                    "Gas coefficient": np.round(b, 4),
                    "Read it as": ["mn cars per $1", "x100 = % per $1", "/100 = mn cars per 1%", "% per 1% (elasticity)"],
                    "$4 to $5, mn cars": np.round(effect, 2)})
print(tab)                                 # also print it to the console
viz_table(tab, title="Four forms, four meanings, one comparable answer")

#| **Exact versus approximate percent.** In a log model, `100 * b` only approximates the percent effect; the exact effect is `100 * (exp(b) - 1)`. For the chip dummy in the log-level model, *b* is about −0.16 and the two readings differ by more than a percentage point. Use the exact one whenever |*b*| is above about 0.10.
b_chip = m_lgl.params["chip"]              # log-level chip-shortage coefficient
print(f"approx: {100 * b_chip:.1f}%   exact: {100 * (np.exp(b_chip) - 1):.1f}%")   # both readings

#| **Rescaling units changes the coefficient, never the story.** Sales in *thousands* of cars and gas in *cents* per gallon: the gas coefficient becomes −4.8 thousand cars per cent. Its standard error is rescaled by the same factor, so the **t-statistic, the p-value and R² do not change**.
d["veh_th"] = d.veh * 1000                 # sales in thousands of cars
d["gas_cts"] = d.gas * 100                 # gas in cents per gallon
m_units = smf.ols("veh_th ~ gas_cts + un + mr + chip", data=d).fit()
# one row per unit choice: estimate, standard error, t-statistic
print(pd.DataFrame({"Estimate": [m_ll.params["gas"], m_units.params["gas_cts"]],
                    "Std. error": [m_ll.bse["gas"], m_units.bse["gas_cts"]],
                    "t value": [m_ll.tvalues["gas"], m_units.tvalues["gas_cts"]]},
                   index=["millions, $", "thousands, cents"]).round(4))

#| **"Holding the other drivers fixed" is not a figure of speech.** On its own, the mortgage rate has a tiny *positive* slope. Add unemployment and it turns negative: rates were high in the 1990s, when jobs were plentiful, and low after 2008, when unemployment was high. Without unemployment in the model, the mortgage rate soaks up part of the job market's effect.
slope_mr = lambda f: smf.ols(f, data=d).fit().params["mr"]   # fit a model, return its mortgage-rate slope
print(pd.Series({"alone": slope_mr("veh ~ mr"), "+ un": slope_mr("veh ~ mr + un"),
                 "+ un + gas": slope_mr("veh ~ mr + un + gas"),
                 "+ chip too": slope_mr("veh ~ mr + un + gas + chip")}).round(3))   # last = drivers-lab model
print(d[["mr", "un", "gas"]].corr().round(2))   # how the drivers move together

#| **A confidence interval, read in words.** `conf_int()` gives 95% intervals; with HAC (Newey–West) standard errors, 12-month window, the gas row reads: *each extra dollar a gallon goes with roughly 200,000 to 770,000 fewer cars a year, holding jobs and rates fixed.* (R's automatic window gives about 160,000 to 810,000: the same message, slightly wider.)
nw = smf.ols("veh ~ gas + un + mr + chip", data=d).fit(cov_type="HAC", cov_kwds={"maxlags": 12})
ci = nw.conf_int()                         # columns 0 and 1 = lower and upper 95% bounds
ci.columns = ["2.5 %", "97.5 %"]
print(pd.concat([nw.params.rename("Estimate"), ci], axis=1).round(3))
