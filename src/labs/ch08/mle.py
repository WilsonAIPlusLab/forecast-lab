#| **The log-likelihood scores any candidate curve.** For each month, a curve gives a probability p of "recession in 12 months". If a recession did follow, the month adds log(p) to the score; if not, it adds log(1 − p). Both are negative, so the best curve is the one whose total is closest to zero. `known` (the months whose 12-month-ahead answer is known) is rebuilt for you in hidden setup code.
import statsmodels.api as sm
y = known["rec_ahead"].to_numpy()        # 0/1 outcome: recession 12 months later?
s = known["spread"].to_numpy()           # today's 10y minus 3m spread, pct. points

def loglik(a, b):                        # total log-likelihood of the curve p = 1 / (1 + exp(-(a + b*s)))
    p = 1 / (1 + np.exp(-(a + b * s)))   # the logistic S-curve
    return np.sum(y * np.log(p) + (1 - y) * np.log(1 - p))

# three candidates: a coin flip for every month, the base rate for every month, and a rough guess that uses the spread
base = np.log(y.mean() / (1 - y.mean()))  # log-odds of the base rate
print({"coin_flip": round(float(loglik(0, 0)), 2), "base_rate": round(float(loglik(base, 0)), 2), "rough_guess": round(float(loglik(-1, -1)), 2)})

#| **Maximum likelihood by hand: IRLS.** No formula gives the best (a, b) directly, so the software climbs the log-likelihood step by step. Each step is a weighted least-squares regression: months with p near 0.5 (weight p(1 − p) = 0.25) count most. Start from a = b = 0 and watch the estimates settle within a few steps.
X = np.column_stack([np.ones(len(s)), s])   # design matrix: a column of 1s (intercept) and the spread
beta = np.zeros(2)                       # starting values: a coin flip for every month
for step in range(1, 7):
    p = 1 / (1 + np.exp(-X @ beta))      # current probabilities
    w = p * (1 - p)                      # IRLS weights: the variance of a 0/1 outcome
    beta = beta + np.linalg.solve(X.T @ (w[:, None] * X), X.T @ (y - p))   # Newton step: (X'WX)^-1 X'(y - p)
    print(f"step {step}: a = {beta[0]:8.5f}  b = {beta[1]:8.5f}  log-likelihood = {loglik(*beta):9.3f}")
logit = sm.Logit(y, X).fit(disp=0)       # statsmodels' version of the same algorithm
print("statsmodels:", logit.params.round(4))

#| **See the peak.** Hold the intercept at its best value and slide the slope. The log-likelihood is a smooth hill, and the fitted model sits on top of it. A steeper hill around the top means the data pin the slope down more precisely: that curvature is where the standard errors come from.
bs = np.arange(-2.2, 0.2001, 0.05)       # candidate slopes
a_hat = logit.params[0]                  # best intercept
viz_lines(bs, **{"Log-likelihood": [loglik(a_hat, b) for b in bs]}, xlab="Slope b on the spread", ylab="Log-likelihood",
          title="Maximum likelihood: the fit picks the slope at the top of the hill")

#| **Does the spread help at all? The likelihood-ratio test.** Compare the fitted model with the base-rate-only model. Twice the gain in log-likelihood follows a chi-squared distribution with 1 degree of freedom (one extra coefficient) if the spread is useless. **McFadden's pseudo-R²** is 1 − ℓ(model) / ℓ(base rate). statsmodels reports all three directly.
print({"LR": round(float(logit.llr), 2), "p_value": float(logit.llr_pvalue), "mcfadden_R2": round(float(logit.prsquared), 4)})

#| **Honest standard errors for overlapping targets.** Each row's target looks 12 months ahead, so neighboring rows share 11 of those 12 future months and their errors move together. The plain fit assumes independent rows, so its standard errors are too small. The **Newey–West (HAC)** fix keeps the same coefficients but adds up how each month's score contribution x(y − p) co-moves with its neighbors', with weights that fade over L lags.
L = 24                                   # lags to include: at least the 11-month overlap, plus room for slow-moving errors
p = logit.predict(X)                     # fitted probabilities
g = X * (y - p)[:, None]                 # score contributions: one row per month
bread = np.linalg.inv(X.T @ (X * (p * (1 - p))[:, None]))   # inverse of the curvature (= the usual covariance)
meat = g.T @ g                           # lag 0
for l in range(1, L + 1):
    G = g[l:].T @ g[:-l]                 # sum of g_t g_{t-l}'
    meat += (1 - l / (L + 1)) * (G + G.T)   # Bartlett weights fade from 1 toward 0
se_hac = np.sqrt(np.diag(bread @ meat @ bread))   # sandwich: bread x meat x bread
hac = sm.Logit(y, X).fit(disp=0, cov_type="HAC", cov_kwds={"maxlags": L})   # statsmodels' built-in version
print(pd.DataFrame({"estimate": logit.params, "se_naive": logit.bse, "se_hac": se_hac, "se_hac_statsmodels": hac.bse,
                    "ratio": se_hac / logit.bse}, index=["Intercept", "spread"]).round(3))

#| **Why so much wider? The errors come in long runs.** Correlate each month's leftover error y − p with the previous month's. Then check that the Newey–West answer barely depends on the exact number of lags.
r = y - p                                # leftover errors
print("neighbor correlation:", round(float(np.corrcoef(r[1:], r[:-1])[0, 1]), 3))
def nw_se(L):                            # Newey-West standard error of the slope for a given number of lags
    meat = g.T @ g
    for l in range(1, L + 1):
        G = g[l:].T @ g[:-l]; meat = meat + (1 - l / (L + 1)) * (G + G.T)
    return float(np.sqrt(np.diag(bread @ meat @ bread))[1])
print({f"lags_{L}": round(nw_se(L), 3) for L in (0, 12, 24, 36)})
