#| **You are the analyst.** Your manager wants two weekly claims series turned into monthly numbers, to sit next to the monthly jobs report. **Initial claims** (`ICSA`) count *new* filings during each week: a **flow**. **Continuing claims** (`CCSA`) count the people *currently* on benefits: a **stock**. Pick the right monthly summary for each, fill the two blanks, and press **Run & check**.
# read each weekly file; index = week-ending Saturday (a real date), one column of values
ic = pd.read_csv("data/ICSA.csv", index_col=0, parse_dates=True)["ICSA"]
cc = pd.read_csv("data/CCSA.csv", index_col=0, parse_dates=True)["CCSA"]

# .resample("MS") groups the weeks by calendar month (labelled by the first day of the month)
# 1. Flow -> a typical week in the month (what FRED reports). Blank: the summary method
ic_m = ic.resample("MS").______()
# 2. Stock -> the number on benefits at month end. Blank: the method that keeps the final week
cc_m = cc.resample("MS").______()

ic_sum = ic.resample("MS").sum()                        # for comparison: the monthly total
print(pd.DataFrame({"avg": ic_m, "sum": ic_sum})["2026-09":"2026-10"])   # Sep and Oct 2026 side by side
print(cc_m.tail(2))                                     # continuing claims at the end of each month
