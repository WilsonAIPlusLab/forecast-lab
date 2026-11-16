# U.S. retail sales excluding food services, $ millions, NOT seasonally adjusted (monthly)
retail = fred("RSXFSN", start=2023)           # Series with a monthly DatetimeIndex from January 2023

# 1. Month-over-month % change: each month vs the month before
mom = 100 * (retail / retail.shift(1) - 1)    # .shift(1) moves values down one row = last month

# 2. Year-over-year % change: each month vs the same month a year earlier
yoy = 100 * (retail / retail.shift(______) - 1)   # blank: how many rows back is "a year earlier"?

# 3. Pull out December 2025 from both series (.loc selects by date label)
dec_mom = mom.loc["2025-12-01"]
dec_yoy = yoy.loc["______"]                   # blank: the date label of December 2025, as "YYYY-MM-DD"

# 4. Side by side. Which one belongs in your reply to the manager?
print(f"MoM {dec_mom:.1f}%   YoY {dec_yoy:.1f}%")
answer = ______                               # blank: the number you would report (dec_mom or dec_yoy)
