from statsmodels.tsa.api import VAR           # vector autoregression model
q = lambda i: fred(i, to="quarter")           # helper: FRED series as quarterly averages
# inflation (annualized %), unemployment (%), funds rate (%); keep quarters where all three exist
y = pd.concat({"infl": 400 * np.log(q("CPIAUCSL")).diff(), "unemp": q("UNRATE"), "ffr": q("FEDFUNDS")}, axis=1).dropna()
y = y["1960-01-01":"2000-12-31"]              # 1960Q1 to 2000Q4
y.index.freq = "QS"                           # quarterly data (quarter-start dates)
m = VAR(y).fit(4)                             # VAR(4); column order = baseline ordering (Fed last)

# responses to a one-s.d. funds-rate shock, row labels h = 0..20, rescaled to a 1-pp surprise hike
oi = m.irf(20).orth_irfs                      # orth_irfs[h, response, impulse]
infl_1pp = pd.Series(oi[:, 0, 2] / oi[0, 2, 2])   # pp of ANNUALIZED inflation, quarter by quarter

# 1. Add up the inflation responses: after h quarters, the price level has absorbed all of them
# blank: the pandas method that returns running totals (1, 1+2, 1+2+3, ...)
cum_infl = infl_1pp.______()

# 2. Each quarter's inflation is at an annual rate (x 4), so one quarter adds only a quarter of it
# blank: the number to divide by to turn summed annualized rates into a % change in the CPI level
price_1pp = cum_infl / ______

# 3. The CPI level 12 quarters (three years) after the hike, in % versus no hike
# blank: the row label for h = 12
price12 = price_1pp.loc[______]
print(round(price_1pp.loc[2], 3), round(price12, 3))   # % difference in the CPI level after 2 and 12 quarters
