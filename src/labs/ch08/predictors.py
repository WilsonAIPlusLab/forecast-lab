#| **Three more candidate predictors**, monthly averages: credit spread (Baa minus 10-year, pct. points), 12-month % change in initial claims (SA), and consumer sentiment (index, NSA, monthly since 1978). The credit spread starts in 1986.
baa = fred("BAA10Y", to="month", start=1986)            # daily credit spread averaged to months
icsa = fred("ICSA", to="month")                         # initial claims, monthly average, SA
claims = (100 * np.log(icsa / icsa.shift(12)))["1986":]   # 12-month log % change; .shift(12) = a year earlier
sent = fred("UMCSENT", start=1986)                      # consumer sentiment index

#| **Line everything up by month** and add the target at 12 and 3 months ahead.
# spread and rec come from the hidden setup; dropna() keeps only months where all five exist
z = pd.DataFrame({"spread": spread, "baa": baa, "claims": claims, "sent": sent, "rec": rec}).dropna()
z["ahead12"] = z["rec"].shift(-12)                      # recession 12 months ahead (shift(-12) pulls values back)
z["ahead3"] = z["rec"].shift(-3)                        # recession 3 months ahead
print(z.index.min().date(), "to", z.index.max().date())   # first and last month in the sample

#| **Train through 2005, test from 2006**, for each horizon and predictor set.
import statsmodels.formula.api as smf
from sklearn.metrics import roc_auc_score
def oos_auc(target, rhs):                               # target = column name; rhs = predictors, e.g. "spread + baa"
    zz = z.dropna(subset=[target])                      # rows with a known answer
    tr, te = zz[:"2005-12"], zz["2006-01":]             # train through 2005, test from 2006
    m = smf.logit(f"{target} ~ {rhs}", data=tr).fit(disp=0)   # f-string builds the formula text
    return roc_auc_score(te[target], m.predict(te))     # out-of-sample AUC
models = {"Spread only": "spread", "+ credit spread": "spread + baa", "+ jobless claims": "spread + claims",
          "+ sentiment": "spread + sent", "All four": "spread + baa + claims + sent"}
# dictionary comprehensions: one AUC per predictor set, one column per horizon
res = pd.DataFrame({"3 months ahead": {k: oos_auc("ahead3", v) for k, v in models.items()},
                    "12 months ahead": {k: oos_auc("ahead12", v) for k, v in models.items()}})
print(res.round(3))

#| **Read the table by column.** Higher AUC is better. Three months out, the spread alone is worse than a coin flip and claims transform the model; twelve months out, extra predictors barely change the AUC. Same numbers as the R version.
viz_table(res, highlight=["3 months ahead", "12 months ahead"], lower_is_better=False, digits=3,   # green = highest AUC
          title="Claims help for the next quarter; a year out, extra predictors barely move the needle")
