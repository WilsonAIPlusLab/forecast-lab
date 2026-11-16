ecom <- fred("MRTSSM4541USN", start = 2000, end = c(2019, 12))   # U.S. e-commerce sales, $ millions, NSA, pre-COVID
dec <- decompose(ecom)                         # classical decomposition; dec$trend = centered 12-month moving average

# 1. How far is each month from its trend, in dollars and in percent?
gap_dollars <- ecom - dec$trend                # $ millions above (+) or below (-) the trend
gap_pct <- 100 * (ecom / dec$trend - 1)        # percent above (+) or below (-) the trend

# 2. Keep only the Decembers. cycle() gives each observation's month number, 1 to 12
dec_dollars <- gap_dollars[cycle(ecom) == 12]  # December gaps in $ millions
dec_pct <- gap_pct[cycle(ecom) == 12]          # December gaps in percent
round(cbind(year = 2000:2019, dollars = dec_dollars, percent = dec_pct), 1)   # 2019 is NA: no trend at the end

# 3. Your verdict: did the dollar boost grow with the business while the percent boost stayed roughly flat?
multiplicative <- TRUE                         # dollars grew about fivefold; percent stayed near +30-40%
