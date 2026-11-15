#| **Freeze the model at the end of 1999:** train on rows dated through December 1999 (their targets run through December 2000), test from January 2000. The model never sees an outcome from the test period.
import statsmodels.api as sm
train = known[:"1999-12"]                    # rows dated up to December 1999 (slice by date)
test = known["2000-01":].copy()              # .copy() so we can add a column safely
fit = sm.Logit(train["rec_ahead"], sm.add_constant(train[["spread"]])).fit(disp=0)   # logit on training rows only
print(fit.params.round(4))

#| **Forecast the test months** with the frozen 1999 model, dated at the month each forecast is about.
test["p"] = fit.predict(sm.add_constant(test[["spread"]]))   # out-of-sample probabilities
shown = test["p"].copy(); shown.index = shown.index + pd.DateOffset(months=12)   # move dates 12 months forward
viz_ts(**{"P(recession), 1999 model": shown}, recessions=True, ylab="probability",
       title="A model frozen in 1999 flagged 2001 and 2008, then raised a long false alarm",
       subtitle="Out-of-sample probability, dated at the month it forecasts; grey = NBER recession")

#| **Score functions:** AUC from scikit-learn, Brier by hand.
from sklearn.metrics import roc_auc_score
brier = lambda p, y: np.mean((p - y) ** 2)   # mean squared gap between probability and 0/1 outcome

#| **Score two test windows** against climatology (the training base rate).
def score(t):
    return {"months": len(t), "AUC": roc_auc_score(t["rec_ahead"], t["p"]), "Brier": brier(t["p"], t["rec_ahead"]),
            "Brier, climatology": brier(train["rec_ahead"].mean(), t["rec_ahead"])}   # constant forecast = training base rate
oos = pd.DataFrame({"2000–2019": score(test[:"2019-12"]), "2000–Oct 2025": score(test)}).T   # one row per window
print(oos.round(4))
viz_table(oos, highlight=["Brier", "Brier, climatology"], digits=3,   # green = lower Brier
          title="The 2022–24 false alarm turns a skillful model into one that loses to a constant")

#| **Where did the damage come from?** Squared errors summed by the year the forecast was made: 2007–08 (the Great Recession's timing) and 2023–24 (the false alarm) top the list.
loss = ((test["p"] - test["rec_ahead"]) ** 2).groupby(test.index.year).sum()   # sum of squared errors within each year
print(loss.sort_values(ascending=False).head(5).round(2))   # five worst years
