from statsmodels.tsa.seasonal import seasonal_decompose   # classical decomposition, like R's decompose()
ecom = fred("MRTSSM4541USN", start="2000-01-01", end="2019-12-01")   # U.S. e-commerce sales, $ millions, NSA, pre-COVID
dec = seasonal_decompose(ecom, model="additive", period=12)          # dec.trend = centered 12-month moving average

# 1. How far is each month from its trend, in dollars and in percent?
gap_dollars = ecom - dec.trend                 # $ millions above (+) or below (-) the trend
gap_pct = 100 * (ecom / ______ - 1)            # blank: what to divide by to get "percent above trend"

# 2. Keep only the Decembers. .index.month gives each observation's month number, 1 to 12
is_dec = ecom.index.month == ______            # blank: December's month number
table = pd.DataFrame({"dollars": gap_dollars[is_dec], "percent": gap_pct[is_dec]}).round(1)
table.index = table.index.year.rename("year")  # label rows by year; 2019 is NaN: no trend at the end
print(table)

# 3. Your verdict: did the dollar boost grow with the business while the percent boost stayed roughly flat?
multiplicative = ______                        # blank: True or False
