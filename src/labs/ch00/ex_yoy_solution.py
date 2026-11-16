# December 2025 retail sales jumped from November. Is retail booming, or is it just December?
retail = fred("RSXFSN", start=2012)           # monthly retail sales, $ millions, not seasonally adjusted

# 1. Pull out three single months (the index is the first day of each month)
dec25 = retail["2025-12-01"]                  # December 2025
nov25 = retail["2025-11-01"]                  # the month before
dec24 = retail["2024-12-01"]                  # the same month a year earlier

# 2. Percent change two ways: 100 * (new / old - 1)
mom = 100 * (dec25 / nov25 - 1)               # month over month: mostly the December effect
yoy = 100 * (dec25 / dec24 - 1)               # year over year: December vs December, seasonality cancels

# 3. Show both side by side
viz_bars([mom, yoy], ["vs Nov 2025 (month over month)", "vs Dec 2024 (year over year)"],
         title="December 2025: a big jump on November, a modest gain on last December",
         xlab="% change in retail sales", sort=False)
