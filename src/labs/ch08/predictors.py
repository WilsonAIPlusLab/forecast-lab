#| **Three more candidate predictors**, monthly averages: credit spread (Baa minus 10-year, pct. points), 12-month % change in initial claims (SA), and consumer sentiment (index, NSA, monthly since 1978). The credit spread starts in 1986.
baa = fred("BAA10Y", to="month", start=1986)
icsa = fred("ICSA", to="month")
claims = (100 * np.log(icsa / icsa.shift(12)))["1986":]
sent = fred("UMCSENT", start=1986)

#| **Line everything up by month** and add the target at 12 and 3 months ahead.
z = pd.DataFrame({"spread": spread, "baa": baa, "claims": claims, "sent": sent, "rec": rec}).dropna()
z["ahead12"] = z["rec"].shift(-12)
z["ahead3"] = z["rec"].shift(-3)
print(z.index.min().date(), "to", z.index.max().date())

#| **Train through 2005, test from 2006**, for each horizon and predictor set.
import statsmodels.formula.api as smf
from sklearn.metrics import roc_auc_score
def oos_auc(target, rhs):
    zz = z.dropna(subset=[target])
    tr, te = zz[:"2005-12"], zz["2006-01":]
    m = smf.logit(f"{target} ~ {rhs}", data=tr).fit(disp=0)
    return roc_auc_score(te[target], m.predict(te))
models = {"Spread only": "spread", "+ credit spread": "spread + baa", "+ jobless claims": "spread + claims",
          "+ sentiment": "spread + sent", "All four": "spread + baa + claims + sent"}
res = pd.DataFrame({"3 months ahead": {k: oos_auc("ahead3", v) for k, v in models.items()},
                    "12 months ahead": {k: oos_auc("ahead12", v) for k, v in models.items()}})
print(res.round(3))

#| **Read the table by column.** Higher AUC is better. Three months out, the spread alone is worse than a coin flip and claims transform the model; twelve months out, extra predictors barely change the AUC. Same numbers as the R version.
viz_table(res, highlight=["3 months ahead", "12 months ahead"], lower_is_better=False, digits=3,
          title="Claims help for the next quarter; a year out, extra predictors barely move the needle")
