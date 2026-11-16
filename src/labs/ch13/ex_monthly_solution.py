#| **Solution.** A flow becomes a weekly *average*: a rate that does not depend on how many weeks the month has. A stock becomes its *end-of-month* value (its monthly average would also be defensible). Never sum a stock: the same people would be counted four or five times.
# read each weekly file; index = week-ending Saturday (a real date), one column of values
ic = pd.read_csv("data/ICSA.csv", index_col=0, parse_dates=True)["ICSA"]
cc = pd.read_csv("data/CCSA.csv", index_col=0, parse_dates=True)["CCSA"]

# .resample("MS") groups the weeks by calendar month (labelled by the first day of the month)
ic_m = ic.resample("MS").mean()                         # 1. flow -> average weekly claims in the month
cc_m = cc.resample("MS").last()                         # 2. stock -> value in the last week of the month

ic_sum = ic.resample("MS").sum()                        # for comparison: the monthly total
print(pd.DataFrame({"avg": ic_m, "sum": ic_sum})["2026-09":"2026-10"])   # Sep and Oct 2026 side by side
print(cc_m.tail(2))                                     # continuing claims at the end of each month
