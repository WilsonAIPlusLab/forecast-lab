# Your manager asks about one client: a 40-year-old, reached on a mobile phone, on the first call
# of this campaign, with Euribor at 4.9%. "What are her chances, should we call her, and how much
# would it matter if our previous campaign with her had been a success?"
logit = smf.logit("yes ~ age + contact + campaign + poutcome + euribor3m", train).fit(disp=0)   # five-fact logit

# Two versions of the same client: identical except for the previous campaign's outcome
her = pd.DataFrame({"age": 40, "contact": "cellular", "campaign": 1, "euribor3m": 4.9,
                    "poutcome": pd.Categorical(["nonexistent", "success"], ["nonexistent", "failure", "success"])})

# 1. Her probability of a yes, in each version (.predict() returns probabilities for a logit)
p = logit.predict(her).to_numpy()

# 2. Odds = p / (1 - p); their ratio equals exp(coefficient), the odds ratio
odds = p / (1 - p)
odds_ratio = odds[1] / odds[0]             # Python counts from 0: [1] is the "success" version

# 3. The same change in percentage points (pp) of probability
change_pp = 100 * (p[1] - p[0])

# 4. Expected value of one call: chance of a yes x $50 per deposit, minus $5 per call
ev_call = p * 50 - 5
print({"p": p.round(3), "odds_ratio": round(float(odds_ratio), 3), "change_pp": round(float(change_pp), 1), "ev_call": ev_call.round(2)})
