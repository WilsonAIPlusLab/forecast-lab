#| **Load the raw series.** `RSXFSN` is U.S. retail sales excluding food services, in $ millions per month, **not seasonally adjusted** (NSA). NSA means you see the calendar's fingerprints: every December spikes, every January and February slumps. We start in 2015 so the picture is not too crowded.
retail <- fred("RSXFSN", start = 2015)        # monthly retail sales, $ millions, NSA, from 2015
viz_ts(retail, recessions = TRUE, ylab = "$ millions",   # gray bands mark recessions
       title = "Every December spikes, every February slumps",
       subtitle = "U.S. retail sales excl. food services, monthly, NSA")

#| **A seasonal plot: one line per year.** Put January to December on the x-axis and draw each year as its own line. If the lines have the same *shape*, the series is seasonal. If they are *stacked* above each other, there is also a trend. `yr()` is a tiny helper that pulls out the 12 months of one year as plain numbers.
yr <- function(y) as.numeric(window(retail, start = c(y, 1), end = c(y, 12)))   # Jan-Dec of year y
viz_lines(1:12, `2021` = yr(2021), `2022` = yr(2022), `2023` = yr(2023),   # x = months 1 to 12, one line per year
          `2024` = yr(2024), `2025` = yr(2025),
          xlab = "month (1 = January)", ylab = "$ millions",
          title = "Same shape every year, a little higher each year")

#| **A seasonal subseries (cycle) plot.** Now flip it: group all Januaries together, then all Februaries, and so on. Each small line shows how *one month* has changed over the years; the flat bar is that month's average. `cycle()` tells you the month number of every observation, and `tapply()` averages the values month by month.
round(tapply(retail, cycle(retail), mean))    # average sales for each calendar month (1 = Jan ... 12 = Dec)
viz_custom("ch02-subseries", date = ts_dates(retail), value = as.numeric(retail),   # course chart: one mini-panel per month
           ylab = "$ millions", source = "FRED, Federal Reserve Bank of St. Louis (RSXFSN)",
           title = "December is the biggest month in every single year")

#| **Classical decomposition with `decompose()`.** It estimates the **trend** with a centred 12-month moving average, the **seasonal** pattern as the average deviation from trend for each calendar month, and calls whatever is left the **remainder** (`random`). The default is *additive*: data = trend + seasonal + remainder, all in dollars.
dc <- decompose(retail)                       # split into trend, seasonal and remainder (additive)
viz_decomp(dc, title = "Classical additive decomposition of retail sales")   # one panel per component

#| **Read the seasonal figure.** `dc$figure` holds the 12 monthly effects in $ millions. December's number is how many dollars above trend a *typical* December sits. Notice the missing trend values at both ends: a centred 12-month average cannot be computed for the first and last six months.
setNames(round(dc$figure), month.abb)         # label the 12 effects Jan ... Dec (month.abb is built into R)
