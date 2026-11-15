#| **Fit a logit.** statsmodels' `Logit` takes the 0/1 target and a design matrix; `add_constant` adds the intercept column. `known` holds the rows whose 12-month-ahead answer is already known (rebuilt in hidden setup).
import statsmodels.api as sm
X = sm.add_constant(known[["spread"]])
logit = sm.Logit(known["rec_ahead"], X).fit(disp=0)
print(logit.params.round(4))

#| **Probit.** Same call with `Probit`. Same estimates as R's `glm(..., binomial(link = "probit"))`.
probit = sm.Probit(known["rec_ahead"], X).fit(disp=0)
print(probit.params.round(4))
print("log-likelihoods:", round(logit.llf, 2), round(probit.llf, 2))

#| **Odds ratio.** exp(slope): how each extra point of spread multiplies the odds of recession a year later.
b = logit.params["spread"]
print("odds ratio:", round(np.exp(b), 4))

#| **Probabilities at chosen spreads.**
grid = sm.add_constant(pd.DataFrame({"spread": [-2, -1, 0, 1, 2, 3]}), has_constant="add")
print(pd.DataFrame({"spread": grid["spread"], "logit": logit.predict(grid), "probit": probit.predict(grid)}).round(4))

#| **Marginal effect at a value:** b × p × (1 − p), in percentage points. statsmodels can also do this with `logit.get_margeff(at="mean")`.
p0, p2 = logit.predict(grid).iloc[[2, 4]]
print("at flat curve:", round(100 * b * p0 * (1 - p0), 2), "| at steep curve:", round(100 * b * p2 * (1 - p2), 2))

#| **Draw the three curves.**
import statsmodels.formula.api as smf
lpm = smf.ols("rec_ahead ~ spread", data=known).fit()
s = np.arange(-3, 4.51, 0.1)
S = sm.add_constant(pd.DataFrame({"spread": s}), has_constant="add")
viz_lines(s, Logit=logit.predict(S), Probit=probit.predict(S), LPM=lpm.predict(pd.DataFrame({"spread": s})),
          xlab="10y minus 3m spread today (pct. points)", ylab="P(recession in 12 months)",
          title="Logit and probit bend to stay between 0 and 1; the straight line does not")
