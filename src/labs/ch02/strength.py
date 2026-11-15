#| **Eight NSA retail categories** (Census monthly retail trade, $ millions).
ids = {"Clothing": "MRTSSM448USN", "Electronics": "MRTSSM443USN",   # dictionary: label -> FRED series ID
       "General merchandise": "MRTSSM452USN", "Building materials": "MRTSSM444USN",
       "E-commerce": "MRTSSM4541USN", "Grocery": "MRTSSM445USN",
       "Gas stations": "MRTSSM447USN", "Restaurants": "MRTSSM722USN"}

#| **STL with R's settings**, wrapped in a function so we can reuse it. The table matches R's to two decimals; a few third decimals differ slightly (for example restaurants, 0.915 here and 0.912 in R).
from statsmodels.tsa.seasonal import STL
def stl_fit(x):                               # robust STL on log sales, with R's stl() settings
    return STL(np.log(x), period=12, seasonal=13, robust=True, seasonal_deg=0,
               seasonal_jump=2, trend_jump=3, low_pass_jump=2).fit(inner_iter=1, outer_iter=15)

#| **Seasonal strength** $F_S = \max(0, 1 - \text{Var}(R)/\text{Var}(S+R))$ and the **peak month** of 2025's seasonal pattern.
def strength(f):                              # seasonal strength F_S, between 0 and 1
    return max(0, 1 - f.resid.var() / (f.seasonal + f.resid).var())   # resid = remainder R, seasonal = S
def peak(f):                                  # month with the largest seasonal effect in 2025
    return f.seasonal["2025"].idxmax().strftime("%b")   # idxmax() = date of the biggest value; "%b" = "Dec"

#| **Run it for every category, twice**: 2010–2019 (before COVID) and 2010 to the latest month.
# dictionary comprehension: one fit per category
pre  = {k: stl_fit(fred(v, start=2010, end="2019-12-01")) for k, v in ids.items()}
full = {k: stl_fit(fred(v, start=2010)) for k, v in ids.items()}   # same, 2010 to the latest month
# one row per category; sort by pre-COVID strength, largest first
tab = pd.DataFrame({"pre_covid": {k: strength(f) for k, f in pre.items()},
                    "with_covid": {k: strength(f) for k, f in full.items()},
                    "peak": {k: peak(f) for k, f in full.items()}}).sort_values("pre_covid", ascending=False)
print(tab.round(3))

#| **Rank them (pre-COVID).** Compare the two columns: one giant shock in the remainder can swamp a perfectly regular seasonal pattern.
# one bar per category
viz_bars(tab["pre_covid"].round(3), title="Before COVID, nearly every kind of store was strongly seasonal",
         subtitle="Seasonal strength F_S from STL on logs (0 = none, 1 = pure seasonality), NSA, 2010–2019",
         highlight=["Clothing", "Gas stations"])   # bars drawn in a highlight color
