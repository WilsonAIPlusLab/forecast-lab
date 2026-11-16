from scipy.stats import norm                   # normal distribution: norm.ppf(0.9) = 1.28
retail = fred("RSAFS", start="2022-01-01")     # U.S. retail & food services sales, $ millions, seasonally adjusted
y = retail.values                              # plain numpy array of the values
n = len(y)                                     # number of months
lo, hi, actual = np.zeros(24), np.zeros(24), np.zeros(24)   # empty slots for the last 24 months
for i in range(24):                            # stand one month before each of the last 24 months
    t = n - 24 + i                             # position of the target month (Python counts from 0)
    past = y[:t]                               # only the data available a month earlier
    s = np.std(np.diff(past), ddof=1)          # typical size of a month-to-month change (ddof=1 matches R's sd)
    lo[i] = past[-1] - norm.ppf(0.9) * s       # naive forecast (last month) minus 1.28 typical changes
    hi[i] = past[-1] + norm.ppf(0.9) * s       # ... plus 1.28 typical changes: an 80% band
    actual[i] = y[t]                           # what really happened

# 1. A hit: the actual value landed inside the band (True/False for each month)
# blank: the upper limit of the band
inside = (actual >= lo) & (actual <= ______)
# 2. Coverage: the share of hits, in percent (the mean of True/False is the share True)
# blank: the True/False array you just made
coverage = 100 * np.mean(______)
# 3. Which side did the misses fall on?
above = np.sum(actual > hi)                    # sales came in higher than the band
# blank: a condition that is True when sales fell short of the band
below = np.sum(______)

print("hits:", inside.sum(), " coverage:", round(coverage, 1), " above:", above, " below:", below)
