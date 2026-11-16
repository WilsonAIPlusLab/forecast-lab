# Real GDP, chained 2017 $ billions, seasonally adjusted annual rate (quarterly)
gdp = fred("GDPC1", start=2024)
q1, q2 = gdp.iloc[-2], gdp.iloc[-1]           # last two quarters (2026 Q2, 2026 Q3); .iloc picks by position

# 1. Quarter-over-quarter % change: what your spreadsheet shows
g_q = 100 * (q2 / q1 - 1)

# 2. Annualize: compound the quarterly growth factor over the 4 quarters of a year
g_ann = 100 * ((q2 / q1) ** ______ - 1)       # blank: how many quarters in a year?

# 3. Log check: 100 x the change in log GDP is close to the quarterly % change
g_log = 100 * (np.log(q2) - ______)           # blank: the log of the earlier quarter's GDP

# 4. Compare with the growth rate BEA published (% change, annualized)
bea = fred("A191RL1Q225SBEA").iloc[-1]
print(f"quarterly {g_q:.2f}   log points {g_log:.2f}   annualized {g_ann:.2f}   BEA {bea:.1f}")   # :.2f = two decimals
