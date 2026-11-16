# Your manager asks: "How much bigger is December than January, in percent?
# And how much bigger than November?" Read the seasonal dummies of a log model.
import statsmodels.formula.api as smf      # R-style regression formulas
retail = fred("RSXFSN", start=2012)        # retail sales, $ millions, NSA
df = pd.DataFrame({"y": retail})           # one column, y = sales
df["trend"] = np.arange(1, len(df) + 1)    # 1, 2, 3, ... counting months
df["month"] = df.index.month               # 1..12, used as a category below
df["covid"] = (df.index == "2020-04-01").astype(int)   # pulse dummy: April 2020 only
train = df[:"2023-12"]                     # fit on 2012 to 2023
fit = smf.ols("np.log(y) ~ trend + C(month) + covid", data=train).fit()   # log sales; January is the base
b = fit.params
print(b.round(4))                          # C(month)[T.2] = February, ..., C(month)[T.12] = December

# 1. December vs January (the base month): exact % gap = 100 * (exp(b) - 1)
dec_vs_jan = 100 * (np.exp(b["C(month)[T.12]"]) - 1)   # December's coefficient is C(month)[T.12]

# 2. December vs November: both are measured from January, so take the difference first
dec_vs_nov = 100 * (np.exp(b["C(month)[T.12]"] - b["C(month)[T.11]"]) - 1)   # Dec minus Nov, both vs January
print(f"Dec vs Jan: {dec_vs_jan:.1f}%   Dec vs Nov: {dec_vs_nov:.1f}%")
