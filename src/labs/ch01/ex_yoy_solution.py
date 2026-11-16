# U.S. retail sales excluding food services, $ millions, NOT seasonally adjusted (monthly)
retail = fred("RSXFSN", start=2023)           # Series with a monthly DatetimeIndex from January 2023

# 1. Month-over-month % change: each month vs the month before
mom = 100 * (retail / retail.shift(1) - 1)    # .shift(1) moves values down one row = last month

# 2. Year-over-year % change: each month vs the same month a year earlier
yoy = 100 * (retail / retail.shift(12) - 1)   # 12 rows back = same month last year

# 3. Pull out December 2025 from both series (.loc selects by date label)
dec_mom = mom.loc["2025-12-01"]
dec_yoy = yoy.loc["2025-12-01"]               # December 2025 vs December 2024

# 4. Side by side. YoY compares December with December, so the holiday spike cancels out
print(f"MoM {dec_mom:.1f}%   YoY {dec_yoy:.1f}%")
answer = dec_yoy                              # the headline-worthy number for unadjusted data
