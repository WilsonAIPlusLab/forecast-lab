# CPI-U, all items, seasonally adjusted, index 1982-84 = 100 (monthly).
# Read the raw CSV, so the unpublished October 2025 stays NaN (fred() would interpolate it).
raw = pd.read_csv("data/CPIAUCSL.csv")
cpi = pd.Series(raw["CPIAUCSL"].values, index=pd.to_datetime(raw["observation_date"]), name="CPIAUCSL").asfreq("MS")

# 1. Year-over-year inflation in percent: compare each month with the same month a year earlier
infl = 100 * (cpi / cpi.shift(______) - 1)

# 2. Look at the last three months. Why is the final value NaN?
print(infl.tail(3))

# 3. The latest month for which inflation can be computed
latest = infl[infl.______()]
print(latest)
