# December 2025 retail sales jumped from November. Is retail booming, or is it just December?
retail <- fred("RSXFSN", start = 2012)        # monthly retail sales, $ millions, not seasonally adjusted

# 1. Pull out three single months (window() cuts a time series between two dates)
dec25 <- as.numeric(window(retail, start = c(2025, 12), end = c(2025, 12)))   # December 2025
nov25 <- as.numeric(window(retail, start = c(2025, 11), end = c(2025, 11)))   # the month before
dec24 <- as.numeric(window(retail, start = c(2024, 12), end = c(2024, 12)))   # the same month a year earlier

# 2. Percent change two ways: 100 * (new / old - 1)
mom <- 100 * (dec25 / ______ - 1)             # blank: compare with the month before
yoy <- 100 * (dec25 / ______ - 1)             # blank: compare with the same month last year

# 3. Show both side by side
viz_bars(c(mom, yoy), c("vs Nov 2025 (month over month)", "vs Dec 2024 (year over year)"),
         title = "December 2025: a big jump on November, a modest gain on last December",
         xlab = "% change in retail sales", sort = FALSE)
