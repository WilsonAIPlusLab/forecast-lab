#| **Fit the logit on the training clients.** The hidden setup loaded the data and made the same split as the previous lab. `smf.logit` fits by maximum likelihood; coefficients are on the log-odds scale and match R's `glm()`.
logit = smf.logit("yes ~ age + contact + campaign + poutcome + euribor3m", train).fit(disp=0)
print(logit.summary2().tables[1].round(4))

#| **Odds ratios with 95% intervals.** Exponentiate the coefficients and their Wald confidence limits (estimate ± 1.96 standard errors), exactly like R's `exp(confint.default())`.
ci = logit.conf_int()
or_table = pd.DataFrame({"odds_ratio": np.exp(logit.params), "lower_95": np.exp(ci[0]), "upper_95": np.exp(ci[1])})
print(or_table.round(3))

#| **Chart them.** One point of Euribor multiplies the odds by about 0.66; each extra call by about 0.91; a past success by about 6.4.
viz_bars(np.exp(logit.params).drop("Intercept").round(2), title="A past success multiplies the odds of a yes by about six",
         xlab="Odds ratio (1 = no effect)")

#| **Back to probabilities** for two clients who differ only in the previous campaign's outcome.
two = pd.DataFrame({"age": 40, "contact": "cellular", "campaign": 1, "euribor3m": 4.9,
                    "poutcome": pd.Categorical(["nonexistent", "success"], ["nonexistent", "failure", "success"])})
print(logit.predict(two).round(3))

#| **Marginal effects.** `get_margeff(at="overall")` is the average marginal effect; `at="mean"` evaluates at the average client. Compare the Euribor row with R's AME and MEM (in probability units; multiply by 100 for percentage points).
print(logit.get_margeff(at="overall").summary_frame().loc["euribor3m", ["dy/dx"]] * 100)
print(logit.get_margeff(at="mean").summary_frame().loc["euribor3m", ["dy/dx"]] * 100)

#| **Discrete change for a past success:** predict every client as "success" and as "nonexistent", then average the difference.
cats = ["nonexistent", "failure", "success"]
p_succ = logit.predict(train.assign(poutcome=pd.Categorical(["success"] * len(train), cats)))
p_none = logit.predict(train.assign(poutcome=pd.Categorical(["nonexistent"] * len(train), cats)))
print(round(100 * (p_succ - p_none).mean(), 1))
