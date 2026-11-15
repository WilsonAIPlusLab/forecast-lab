#| **Load two monthly series from FRED.** `USREC` is the NBER recession indicator (1 = recession month). The **term spread** is the 10-year Treasury yield minus the 3-month bill rate, in percentage points. Building a DataFrame from both Series lines them up by date.
rec = fred("USREC", start=1959)
spread = fred("GS10", start=1959) - fred("TB3MS", start=1959)
d = pd.DataFrame({"spread": spread, "rec": rec}).dropna()

#| **Look before you model.** Grey bars are NBER recessions.
viz_ts(**{"10y minus 3m spread": d["spread"]}, recessions=True, ylab="pct. points",
       title="The spread dips below zero ahead of most recessions",
       subtitle="Monthly average 10-year Treasury yield minus 3-month bill rate; grey = NBER recession")

#| **Build the forward-looking target.** `shift(-12)` pulls each value 12 months back, so row *t* holds the recession indicator for month *t* + 12. The last 12 rows become `NaN`: their answer is still in the future.
d["rec_ahead"] = d["rec"].shift(-12)
print(d.tail(14))

#| **Check the shift by eye.** January 2008 is the first recession month, so January 2007 should have `rec_ahead = 1` while `rec` is still 0.
print(d["2006-11":"2007-03"])

#| **Linear probability model.** Ordinary least squares on the 0/1 target, with statsmodels' formula interface (it drops the `NaN` rows).
import statsmodels.formula.api as smf
lpm = smf.ols("rec_ahead ~ spread", data=d).fit()
print(lpm.params)

#| **Impossible probabilities.** Same numbers as the R version.
p_lpm = lpm.predict(d)
print("range:", p_lpm.min().round(3), "to", p_lpm.max().round(3), "| months below 0:", int((p_lpm < 0).sum()))
viz_ts(**{'LPM "probability"': p_lpm}, recessions=True,
       title=f"A straight line predicts a negative chance of recession in {int((p_lpm < 0).sum())} months",
       subtitle="Fitted values from OLS of rec_ahead on spread, dated at the forecast month t")
