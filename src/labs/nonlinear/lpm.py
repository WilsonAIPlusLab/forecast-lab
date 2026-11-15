#| **Load the clients.** Each row is one client of a Portuguese bank who was phoned in a marketing campaign. The target `y` says whether the client subscribed to a term deposit. We code it as `yes` = 1 or 0. Only about 11% said yes. Making `poutcome` a categorical with "nonexistent" first sets "never contacted before" as the baseline, as in the R tab.
import statsmodels.formula.api as smf
bank = pd.read_csv("data/bank_marketing.csv")
bank["yes"] = (bank["y"] == "yes").astype(int)
bank["poutcome"] = pd.Categorical(bank["poutcome"], ["nonexistent", "failure", "success"])
print(bank["yes"].mean())

#| **Hold out a test set, stratified by outcome.** The file has no dates and its rows are in random order, so a time split is impossible. `cumcount()` numbers each client within its own class (yes or no); positions 0, 1, 2 of every 10 go to the test set: 30% of each class. The R tab makes exactly the same split. In your own projects use `train_test_split(..., stratify=y, random_state=...)`.
pos = bank.groupby("y").cumcount()
is_test = pos % 10 < 3
train, test = bank[~is_test].copy(), bank[is_test].copy()
print(len(train), len(test), train["yes"].sum(), test["yes"].sum())

#| **Three models, same five pre-call facts.** `smf.ols` is the linear probability model; `smf.logit` and `smf.probit` fit the two S-curves by maximum likelihood. The coefficients match R's `lm()` and `glm()`.
f = "yes ~ age + contact + campaign + poutcome + euribor3m"
lpm = smf.ols(f, train).fit()
logit = smf.logit(f, train).fit(disp=0)
probit = smf.probit(f, train).fit(disp=0)

#| **Count the impossible predictions.** The straight line gives some clients a negative probability; the logit and probit never leave the 0–1 interval.
fits = {"LPM": lpm.fittedvalues, "Logit": logit.predict(train), "Probit": probit.predict(train)}
print(pd.DataFrame({k: {"below_0": (v < 0).sum(), "above_1": (v > 1).sum(), "min": v.min(), "max": v.max()}
                    for k, v in fits.items()}).T)

#| **See it.** Each dot is one client: logit probability across, LPM probability up. Dots below zero are impossible forecasts.
viz_scatter(fits["Logit"], fits["LPM"], fit=False, xlab="Logit probability", ylab="LPM probability",
            title="The straight line predicts negative probabilities for some clients")

#| **Do they rank clients differently?** Hardly. On the test clients the AUC (the share of correctly ordered yes/no pairs, explained later) is almost the same for all three. The LPM's problem is its numbers, not its ranking.
from sklearn.metrics import roc_auc_score
print({k: round(roc_auc_score(test["yes"], m.predict(test)), 4) for k, m in {"LPM": lpm, "Logit": logit, "Probit": probit}.items()})
