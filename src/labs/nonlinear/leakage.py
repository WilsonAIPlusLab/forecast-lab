#| **The honest model**: five facts known before the bank dials (hidden setup: same data and split).
from sklearn.metrics import roc_auc_score  # AUC = probability a random subscriber scores above a random non-subscriber
honest = smf.logit("yes ~ age + contact + campaign + poutcome + euribor3m", train).fit(disp=0)   # logit, pre-call facts only
print(round(roc_auc_score(test["yes"], honest.predict(test)), 4))   # test AUC of the honest model

#| **Add `duration`, the call length in seconds,** and score the same test clients.
leaky = smf.logit("yes ~ age + contact + campaign + poutcome + euribor3m + duration", train).fit(disp=0)   # plus call length
print(round(roc_auc_score(test["yes"], leaky.predict(test)), 4))

#| **Why so good?** The median subscriber's call is almost three times as long; none of the 407 calls under a minute ended in a yes.
print(bank.groupby("y")["duration"].median())   # median call length (seconds) for "no" and "yes"
print({"calls_under_60s": int((bank["duration"] < 60).sum()),
       "yes_among_them": int(((bank["duration"] < 60) & (bank["yes"] == 1)).sum())})

#| **Would you know it in time?** No: the call has not happened when you decide whom to call. Odds ratio per extra minute of call:
print(np.exp(60 * leaky.params["duration"]))   # odds ratio for 60 more seconds = exp(60 x per-second slope)

#| **The lesson in one chart.**
# two bars: honest vs leaky test AUC
viz_bars(pd.Series({"Before the call (honest)": roc_auc_score(test["yes"], honest.predict(test)),
                    "With call duration (leak)": roc_auc_score(test["yes"], leaky.predict(test))}),
         sort=False, xlab="Test AUC (0.5 = coin flip, 1 = perfect)",
         title="One leaked column turns a decent model into a 'miracle'")
