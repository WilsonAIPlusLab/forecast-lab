from statsmodels.tsa.api import VAR           # vector autoregression model
q = lambda i: fred(i, to="quarter")           # helper: FRED series as quarterly averages
# inflation (annualized %), unemployment (%), funds rate (%); keep quarters where all three exist
y = pd.concat({"infl": 400 * np.log(q("CPIAUCSL")).diff(), "unemp": q("UNRATE"), "ffr": q("FEDFUNDS")}, axis=1).dropna()
y = y["1960-01-01":"2000-12-31"]              # 1960Q1 to 2000Q4
y.index.freq = "QS"                           # quarterly data (quarter-start dates)
m = VAR(y).fit(4)                             # VAR(4); column order = baseline ordering (Fed last)

# responses to a one-standard-deviation funds-rate shock; orth_irfs[h, response, impulse], h = 0..20
oi = m.irf(20).orth_irfs
r = pd.DataFrame(oi[:, :, 2], columns=y.columns)   # impulse 2 = ffr (third column); row labels = h
size = r.loc[0, "ffr"]                        # how big that shock is: the funds rate's own jump on impact (pp)

# 1. Rescale the unemployment response to a 1-percentage-point surprise hike
unemp_1pp = r["unemp"] / size                 # responses are linear: divide by the shock size

# 2. The response 8 quarters (two years) after the hike
at8 = unemp_1pp.loc[8]                        # row label 8 = two years after the shock

# 3. When does unemployment peak?
peak_q = int(unemp_1pp.idxmax())              # .idxmax() = label (quarter) of the largest response
print(round(size, 4), round(at8, 4), peak_q)  # the three numbers for your CFO
