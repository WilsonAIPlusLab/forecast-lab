# U.S. retail sales excluding food services, $ millions, NOT seasonally adjusted (monthly)
retail <- fred("RSXFSN", start = 2023)        # monthly ts starting January 2023

# 1. Month-over-month % change: each month vs the month before
mom <- 100 * (retail / stats::lag(retail, -1) - 1)   # stats::lag(x, -1) = last month's value

# 2. Year-over-year % change: each month vs the same month a year earlier
yoy <- 100 * (retail / stats::lag(retail, -12) - 1)  # -12 = the value from 12 months earlier

# 3. Pull out December 2025 from both series
dec_mom <- window(mom, start = c(2025, 12), end = c(2025, 12))   # window() keeps only these dates
dec_yoy <- window(yoy, start = c(2025, 12), end = c(2025, 12))   # December 2025 vs December 2024

# 4. Side by side. YoY compares December with December, so the holiday spike cancels out
round(c(MoM = dec_mom, YoY = dec_yoy), 1)
answer <- dec_yoy                             # the headline-worthy number for unadjusted data
