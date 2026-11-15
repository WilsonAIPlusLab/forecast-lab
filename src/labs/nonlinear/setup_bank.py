# Hidden setup shared by the bank-marketing labs: load, code the target, split (same as the first lab).
import statsmodels.formula.api as smf
bank = pd.read_csv("data/bank_marketing.csv")
bank["yes"] = (bank["y"] == "yes").astype(int)
bank["poutcome"] = pd.Categorical(bank["poutcome"], ["nonexistent", "failure", "success"])
pos = bank.groupby("y").cumcount()
is_test = pos % 10 < 3
train = bank[~is_test].copy()
test = bank[is_test].copy()
