# CPI-U, all items, seasonally adjusted, index 1982-84 = 100 (monthly).
# Read the raw CSV, so the unpublished October 2025 stays NaN (fred() would interpolate it).
raw = pd.read_csv("data/CPIAUCSL.csv")        # DataFrame: observation_date and CPIAUCSL columns
# Series indexed by date; asfreq("MS") declares monthly (month-start) frequency
cpi = pd.Series(raw["CPIAUCSL"].values, index=pd.to_datetime(raw["observation_date"]), name="CPIAUCSL").asfreq("MS")

# 1. Year-over-year inflation in percent: compare each month with the same month a year earlier
infl = 100 * (cpi / cpi.shift(12) - 1)        # shift(12) = the value from 12 rows (months) earlier

# 2. Look at the last three months. Why is the final value NaN?
print(infl.tail(3))                           # last 3 values

# 3. The latest month for which inflation can be computed
latest = infl[infl.last_valid_index()]        # date of the last non-missing value, then its value
print(latest)
