#| **Load the clients.** Each row is one client of a Portuguese bank who was phoned in a marketing campaign. The target `y` says whether the client subscribed to a term deposit. We code it as `yes` = 1 or 0. Only about 11% said yes. Making `poutcome` a categorical with "nonexistent" first sets "never contacted before" as the baseline, as in the R tab.
import statsmodels.formula.api as smf      # R-style formulas
bank = pd.read_csv("data/bank_marketing.csv")
bank["yes"] = (bank["y"] == "yes").astype(int)   # "yes"/"no" -> 1/0
bank["poutcome"] = pd.Categorical(bank["poutcome"], ["nonexistent", "failure", "success"])   # first = baseline
print(bank["yes"].mean())                  # mean of a 0/1 column = share who said yes

#| **Hold out a test set, stratified by outcome.** The file has no dates and its rows are in random order, so a time split is impossible. `cumcount()` numbers each client within its own class (yes or no); positions 0, 1, 2 of every 10 go to the test set: 30% of each class. The R tab makes exactly the same split. In your own projects use `train_test_split(..., stratify=y, random_state=...)`.
pos = bank.groupby("y").cumcount()         # 0, 1, 2, ... separately within "yes" and "no"
is_test = pos % 10 < 3                     # % = remainder: positions 0, 1, 2 of every 10 -> test
train, test = bank[~is_test].copy(), bank[is_test].copy()   # ~ means "not"
print(len(train), len(test), train["yes"].sum(), test["yes"].sum())

#| **Three models, same five pre-call facts.** `smf.ols` is the linear probability model; `smf.logit` and `smf.probit` fit the two S-curves by maximum likelihood. The coefficients match R's `lm()` and `glm()`.
f = "yes ~ age + contact + campaign + poutcome + euribor3m"   # one formula shared by all three models
lpm = smf.ols(f, train).fit()              # straight line (OLS) on a 0/1 target
logit = smf.logit(f, train).fit(disp=0)    # logistic S-curve (disp=0 hides fitting messages)
probit = smf.probit(f, train).fit(disp=0)  # normal-distribution S-curve

#| **Count the impossible predictions.** The straight line gives some clients a negative probability; the logit and probit never leave the 0–1 interval.
fits = {"LPM": lpm.fittedvalues, "Logit": logit.predict(train), "Probit": probit.predict(train)}   # training probabilities
# for each model: count below 0, count above 1, smallest and largest value
print(pd.DataFrame({k: {"below_0": (v < 0).sum(), "above_1": (v > 1).sum(), "min": v.min(), "max": v.max()}
                    for k, v in fits.items()}).T)

#| **See it.** Each dot is one client: logit probability across, LPM probability up. Dots below zero are impossible forecasts.
viz_scatter(fits["Logit"], fits["LPM"], fit=False, xlab="Logit probability", ylab="LPM probability",   # fit=False: no fitted line
            title="The straight line predicts negative probabilities for some clients")

#| **Do they rank clients differently?** Hardly. On the test clients the AUC (the share of correctly ordered yes/no pairs, explained later) is almost the same for all three. The LPM's problem is its numbers, not its ranking.
from sklearn.metrics import roc_auc_score
# test-set AUC of each model (dict comprehension)
print({k: round(roc_auc_score(test["yes"], m.predict(test)), 4) for k, m in {"LPM": lpm, "Logit": logit, "Probit": probit}.items()})
