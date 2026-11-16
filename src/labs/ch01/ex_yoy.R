# U.S. retail sales excluding food services, $ millions, NOT seasonally adjusted (monthly)
retail <- fred("RSXFSN", start = 2023)        # monthly ts starting January 2023

# 1. Month-over-month % change: each month vs the month before
mom <- 100 * (retail / stats::lag(retail, -1) - 1)   # stats::lag(x, -1) = last month's value

# 2. Year-over-year % change: each month vs the same month a year earlier
yoy <- 100 * (retail / stats::lag(retail, ______) - 1)   # blank: how many months back (mind the sign)

# 3. Pull out December 2025 from both series
dec_mom <- window(mom, start = c(2025, 12), end = c(2025, 12))            # window() keeps only these dates
dec_yoy <- window(yoy, start = c(______, ______), end = c(2025, 12))      # blank: year and month of December 2025

# 4. Side by side. Which one belongs in your reply to the manager?
round(c(MoM = dec_mom, YoY = dec_yoy), 1)
answer <- ______                              # blank: the number you would report (dec_mom or dec_yoy)
