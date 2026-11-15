#| **One series, many views.** `RSXFSN` is U.S. retail sales excluding food services, in millions of dollars, **not seasonally adjusted** (NSA), so every December spikes.
retail = fred("RSXFSN", start=2015)           # monthly retail sales, $ millions, NSA

#| **Differences** in the data's own units: `diff()` is $x_t - x_{t-1}$, the change in millions of dollars from the previous month. The first value becomes `NaN` because there is no previous month.
d1 = retail.diff()                            # month-to-month change, $ millions
print(d1["2026-01":])                         # show 2026 onward

#| **Percent changes.** `shift(1)` is last month and `shift(12)` the same month a year earlier. Dividing by hand keeps the meaning explicit.
mom = 100 * (retail / retail.shift(1) - 1)    # % change from the previous month
yoy = 100 * (retail / retail.shift(12) - 1)   # % change from the same month last year

#| **Logs turn growth into differences.** $100 \times \Delta\log x_t$ is almost exactly the percent change for small moves and drifts away for big ones, such as December's holiday jump and January's drop.
dlog = 100 * np.log(retail).diff()            # log change x 100, close to % change for small moves
print(pd.DataFrame({"mom": mom, "dlog": dlog})["2025-11":"2026-04"].round(2))   # side by side, Nov 2025 to Apr 2026

#| **Annualized rates** compound one month's growth over 12 months. Use **seasonally adjusted** data only, so we switch to `RSAFS` (retail and food services, SA).
sa = fred("RSAFS", start=2015)                # seasonally adjusted retail & food services, $ millions
ann = 100 * ((sa / sa.shift(1)) ** 12 - 1)    # monthly growth factor compounded over 12 months, in %

#| **Index to 100**: divide by the 2019 average. Every value now reads as "percent of the 2019 level".
idx = 100 * retail / retail["2019"].mean()    # 100 = the 2019 average

#| **Side by side** for the last six months. MoM zigzags with the calendar; YoY is steadier.
# one row per month; .values takes the raw numbers; ann.reindex() lines the SA series up with retail's dates
tab = pd.DataFrame({"Month": retail.index.strftime("%b %Y"), "Level ($M)": retail.values,
                    "MoM %": mom.values, "YoY %": yoy.values, "100 x dlog": dlog.values,
                    "Annualized % (SA)": ann.reindex(retail.index).values,
                    "Index 2019=100": idx.values}).tail(6)   # keep the last 6 months
print(tab.round(2).to_string(index=False))    # print without the row numbers
viz_table(tab, digits=1, title="Six months of retail sales, six ways to read them")   # same table, formatted

#| **See the difference**: MoM growth of NSA data shows the calendar, YoY growth shows the trend.
# **{...} passes dictionary entries as named arguments, so names can contain spaces
viz_ts(**{"Month over month": mom["2019":], "Year over year": yoy["2019":]}, ylab="% change",
       title="For seasonal data, MoM shows the calendar; YoY shows the trend")
