#| **Flows add up.** Retail sales are dollars spent **during** each month, so a quarter's sales are the sum of its months. `resample("QS")` groups the months into quarters (labelled by the quarter's first day); `.sum()` combines them.
retail = fred("RSXFSN", start=2015)           # monthly retail sales, $ millions (a flow)
retail_q = retail.resample("QS").sum()        # group months into quarters, then add them up
print(retail_q["2025":])                      # slice by date: 2025 Q1 onward

#| **Stocks do not add up.** Payroll employment counts people on payrolls **at a point in time**. Use the quarter's average or its last month. Unlike R's `aggregate()`, pandas keeps an incomplete final quarter, so we drop quarters with fewer than three months.
jobs = fred("PAYEMS", start=2019)             # payroll employment, thousands of jobs (a stock)
g = jobs.resample("QS")                       # quarterly groups, not yet combined
full = g.count() == 3                         # True for quarters that have all 3 months
jobs_avg, jobs_end = g.mean()[full], g.last()[full]   # quarterly average and last month, complete quarters only

#| **The choice matters most when things move fast**: 2020 Q2 (thousands of jobs).
# build a table with one column per version; .loc["2020"] keeps the rows dated 2020
print(pd.DataFrame({"average": jobs_avg, "end_of_quarter": jobs_end, "gap": jobs_end - jobs_avg}).loc["2020"].round())

#| **Daily data: the yield-curve spread** (10-year minus 3-month Treasury, percentage points). It is a rate, so summing is meaningless. `fred()` drops blank holidays.
spread = fred("T10Y3M").dropna()              # daily spread; dropna() removes any missing days

#| **Two monthly versions**: the average of the month's business days (what `fred("T10Y3M", to="month")` returns) and the month-end reading.
avg = spread.resample("MS").mean()            # monthly average ("MS" = month start labels)
eom = spread.resample("MS").last()            # month-end reading: last business day of each month
print(np.allclose(avg.values, fred("T10Y3M", to="month").values))   # True: matches fred()'s monthly average

#| **Count inverted months** since 2019 under each rule.
ra, re_ = avg["2019":], eom["2019":]          # both versions from 2019 on (re_ avoids clashing with the re module)
# summing True/False values counts the Trues; int() turns the result into a plain number
print({"days_inverted": int((spread["2019":] < 0).sum()), "months_avg_inv": int((ra < 0).sum()),
       "months_eom_inv": int((re_ < 0).sum()), "months_disagree": int(((ra < 0) != (re_ < 0)).sum())})

#| **Plot both.** Same daily data, two monthly series.
# **{...} passes dictionary entries as named arguments, so series names can contain spaces
viz_ts(**{"Monthly average": ra, "Month-end": re_}, ylab="percentage points", recessions=True,
       title="Same daily data, two monthly series: average vs. month-end spread")
