#| **Load the raw series**: U.S. retail sales excluding food services, $ millions per month, **not seasonally adjusted** (NSA).
retail = fred("RSXFSN", start=2015)           # monthly retail sales, $ millions, NSA, from 2015
viz_ts(retail, recessions=True, ylab="$ millions",   # gray bands mark recessions
       title="Every December spikes, every February slumps",
       subtitle="U.S. retail sales excl. food services, monthly, NSA")

#| **A seasonal plot: one line per year.** `retail[str(y)]` selects the 12 months of year `y`.
yr = lambda y: retail[str(y)].values          # lambda = a one-line function: Jan-Dec of year y as plain numbers
# x = months 1 to 12; the dictionary comprehension makes one named line per year, 2021-2025
viz_lines(range(1, 13), **{str(y): yr(y) for y in range(2021, 2026)},
          xlab="month (1 = January)", ylab="$ millions",
          title="Same shape every year, a little higher each year")

#| **A seasonal subseries (cycle) plot.** Group all Januaries together, all Februaries, and so on. `groupby(retail.index.month)` plays the role of R's `tapply(retail, cycle(retail), mean)`.
print(retail.groupby(retail.index.month).mean().round(0))   # average sales for each calendar month (1 = Jan ... 12 = Dec)
# course chart: one mini-panel per month; dates passed as "YYYY-MM-DD" text
viz_custom("ch02-subseries", date=[d.strftime("%Y-%m-%d") for d in retail.index], value=retail.tolist(),
           ylab="$ millions", source="FRED, Federal Reserve Bank of St. Louis (RSXFSN)",
           title="December is the biggest month in every single year")

#| **Classical additive decomposition.** `seasonal_decompose` from statsmodels does the same as R's `decompose()`: a centred 12-month moving average for the trend and monthly averages of the detrended series for the seasonal part.
from statsmodels.tsa.seasonal import seasonal_decompose
dc = seasonal_decompose(retail, model="additive", period=12)   # trend + seasonal + remainder, 12 months per cycle
viz_decomp(dc, title="Classical additive decomposition of retail sales")   # one panel per component

#| **The seasonal figure**: twelve monthly effects in $ millions.
# the seasonal pattern repeats, so its first 12 values (Jan-Dec 2015) are the 12 monthly effects; relabel them by month
print(dc.seasonal.iloc[:12].set_axis(["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]).round(0))
