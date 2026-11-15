#| **Load the raw series**: U.S. retail sales excluding food services, $ millions per month, **not seasonally adjusted** (NSA).
retail = fred("RSXFSN", start=2015)
viz_ts(retail, recessions=True, ylab="$ millions",
       title="Every December spikes, every February slumps",
       subtitle="U.S. retail sales excl. food services, monthly, NSA")

#| **A seasonal plot: one line per year.** `retail[str(y)]` selects the 12 months of year `y`.
yr = lambda y: retail[str(y)].values
viz_lines(range(1, 13), **{str(y): yr(y) for y in range(2021, 2026)},
          xlab="month (1 = January)", ylab="$ millions",
          title="Same shape every year, a little higher each year")

#| **A seasonal subseries (cycle) plot.** Group all Januaries together, all Februaries, and so on. `groupby(retail.index.month)` plays the role of R's `tapply(retail, cycle(retail), mean)`.
print(retail.groupby(retail.index.month).mean().round(0))
viz_custom("ch02-subseries", date=[d.strftime("%Y-%m-%d") for d in retail.index], value=retail.tolist(),
           ylab="$ millions", source="FRED, Federal Reserve Bank of St. Louis (RSXFSN)",
           title="December is the biggest month in every single year")

#| **Classical additive decomposition.** `seasonal_decompose` from statsmodels does the same as R's `decompose()`: a centred 12-month moving average for the trend and monthly averages of the detrended series for the seasonal part.
from statsmodels.tsa.seasonal import seasonal_decompose
dc = seasonal_decompose(retail, model="additive", period=12)
viz_decomp(dc, title="Classical additive decomposition of retail sales")

#| **The seasonal figure**: twelve monthly effects in $ millions.
print(dc.seasonal.iloc[:12].set_axis(["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]).round(0))
