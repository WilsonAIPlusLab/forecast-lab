#| **Fit the logit on every month whose answer is known** (January 1959 to October 2025).
import statsmodels.api as sm
logit = sm.Logit(known["rec_ahead"], sm.add_constant(known[["spread"]])).fit(disp=0)   # P(recession in 12 months) vs spread
print(logit.params.round(4))

#| **Predict every month, including the last 12** (genuine forecasts).
d["p"] = logit.predict(sm.add_constant(d[["spread"]]))   # probability for every row of d, not just known ones
print(d[["spread", "p"]].tail(3))                         # last 3 rows

#| **Date each probability at the month it is about** (12 months later), the way the New York Fed draws its chart.
prob = d["p"].copy()
prob.index = prob.index + pd.DateOffset(months=12)        # move every date 12 months forward
viz_ts(**{"P(recession)": prob}, recessions=True, ylab="probability",
       title="The yield-curve model's recession probability, dated at the month it forecasts",
       subtitle="Logit on the 10y minus 3m spread 12 months earlier; grey = NBER recession")

#| **The New York Fed's published coefficients** (a probit estimated on 1959–2009), applied to our spread. `norm.cdf` is the probit curve.
from scipy.stats import norm
d["p_nyfed"] = norm.cdf(-0.5333 - 0.6330 * d["spread"])   # NY Fed intercept and slope
print((100 * d[["p", "p_nyfed"]].tail(1)).round(1))       # latest month, both models, in %

#| **The 2022–24 episode:** the model's highest probability and the month it was about.
recent = d["2022-01":]                                    # rows from 2022 onward
made = recent["p"].idxmax()                               # .idxmax() = date of the highest probability
print("made in", made.strftime("%b %Y"), "| about", (made + pd.DateOffset(months=12)).strftime("%b %Y"), "| prob", round(recent["p"].max(), 3))

#| **Today's reading.**
last = d.iloc[-1]                                         # .iloc[-1] = the most recent row
viz_kpi(title="The yield curve's latest recession signal",
        **{"Spread, Oct 2026 (pct. points)": round(last["spread"], 2),
           "P(recession in Oct 2027), our logit": f"{100 * last['p']:.1f}%",   # f-string: 1 decimal and a % sign
           "Same, NY Fed coefficients": f"{100 * last['p_nyfed']:.1f}%"})
