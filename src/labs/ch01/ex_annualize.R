# Real GDP, chained 2017 $ billions, seasonally adjusted annual rate (quarterly)
gdp <- fred("GDPC1", start = 2024)
q <- as.numeric(tail(gdp, 2))                 # last two quarters (2026 Q2, 2026 Q3) as plain numbers

# 1. Quarter-over-quarter % change: what your spreadsheet shows
g_q <- 100 * (q[2] / q[1] - 1)

# 2. Annualize: compound the quarterly growth factor over the 4 quarters of a year
g_ann <- 100 * ((q[2] / q[1])^______ - 1)     # blank: how many quarters in a year?

# 3. Log check: 100 x the change in log GDP is close to the quarterly % change
g_log <- 100 * (log(q[2]) - ______)           # blank: the log of the earlier quarter's GDP

# 4. Compare with the growth rate BEA published (% change, annualized)
bea <- as.numeric(tail(fred("A191RL1Q225SBEA"), 1))
round(c(quarterly = g_q, log_points = g_log, annualized = g_ann, BEA = bea), 2)
