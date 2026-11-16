# Your CFO asks: "What does the yield curve say about a recession a year from now, in plain words?
# And how much would it change if the curve flattened by a quarter point?"
# The DataFrame d (spread, rec, rec_ahead; dates in the index) and known (rows with a known answer) are ready.
import statsmodels.formula.api as smf          # R-style formulas: "y ~ x"
# blank: the formula-API function for logistic regression
logit = smf.______("rec_ahead ~ spread", data=known).fit(disp=0)   # disp=0 hides the optimizer log

latest = d.tail(1)                             # the latest month: spread known, outcome 12 months later not yet
print(latest.index[0], latest["spread"].iloc[0])   # the month and its spread, in percentage points

# 1. Probability that the month 12 months from now is a recession month
p_now = float(logit.predict(latest).iloc[0])

# 2. The same forecast if the spread were 25 basis points LOWER (a flatter curve)
# blank: 25 basis points, written in the spread's units (percentage points)
p_flat = float(logit.predict(pd.DataFrame({"spread": latest["spread"] - ______})).iloc[0])
change_pp = 100 * (p_flat - p_now)             # change in percentage points of probability

# 3. Compare with the base rate: the share of all known months followed by a recession
# blank: the column that holds the 0/1 target
base = known["______"].mean()
ratio_to_base = p_now / base                   # above 1 = more risk than usual, below 1 = less
print({"p_now": round(p_now, 3), "p_flat": round(p_flat, 3), "change_pp": round(change_pp, 2),
       "base": round(float(base), 3), "ratio_to_base": round(float(ratio_to_base), 2)})
