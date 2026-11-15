#| **Open the raw file first.** Every bundled series is a plain CSV downloaded from FRED: one column of dates, one column of values. `read.csv()` gives you a *data frame*. Look at `str()`: the date column arrives as **text** (`chr`), so R has no idea yet that this is a time series.
raw <- read.csv("data/UNRATE.csv")
head(raw, 3)
str(raw)

#| **Turn the column into a `ts` object.** A `ts` stores the values plus two facts: when the series **starts** and how many observations make one year (its **frequency**: 12 for monthly, 4 for quarterly, 1 for annual). From those two facts R can work out the date of every observation.
unrate <- ts(raw$UNRATE, start = c(1948, 1), frequency = 12)

#| **Ask the series about itself.** `start()` and `end()` return *(year, period)* pairs, so `2026 10` means October 2026. `time()` gives each observation's date as a decimal year: January is `.000`, February `.083` (1/12), and so on. Get in the habit of running these four lines on every new series.
start(unrate)
end(unrate)
frequency(unrate)
tail(time(unrate), 3)

#| **Cut out a time window.** `window()` subsets by date, not by row number, so you never have to count rows. Here: January 2019 through December 2021, which spans the COVID spike to 14.8% in April 2020.
covid <- window(unrate, start = c(2019, 1), end = c(2021, 12))
covid

#| **A month that does not exist.** One value in this file is blank, so `read.csv()` stored it as `NA`. It is **October 2025**: the federal government shut down from October 1 to November 12, 2025, and the Census Bureau interviewers who run the household survey never collected that month. It will never be filled in. Keep the `NA` in place: a `ts` assumes evenly spaced observations, so deleting the row would silently shift every later value one month earlier.
raw[is.na(raw$UNRATE), ]
window(unrate, start = c(2025, 8), end = c(2025, 12))

#| **`fred()` does the loading in one line.** It reads the CSV, detects the frequency from the date spacing, and returns a `ts`. On payroll jobs (no gaps) the hand-built series and the `fred()` series are identical. On a series with a short gap, such as `UNRATE`, `fred()` prints a **Note** and fills the missing month by *linear interpolation* (the average of its neighbors), because most models cannot handle `NA`. That is convenient for modeling, but the filled value is an estimate, not published data. When you need to know what was actually published, read the CSV as above.
raw_pay <- read.csv("data/PAYEMS.csv")
pay <- ts(raw_pay$PAYEMS, start = c(1939, 1), frequency = 12)
all.equal(pay, fred("PAYEMS"))
window(fred("UNRATE"), start = c(2025, 8), end = c(2025, 12))

#| **Five vital signs of the economy.** We put each series in the form analysts quote it: the unemployment *rate* as a level, and the other four as **percent change from a year earlier**. `stats::lag(x, -12)` shifts a monthly series back 12 months, and R lines the two up by date before dividing. GDP is quarterly, so its year-ago lag is 4. CPI has the same October 2025 gap as unemployment, so we build it from its CSV too: we do not want an inflation rate that rests on an interpolated month.
yoy <- function(x) 100 * (x / stats::lag(x, -frequency(x)) - 1)
raw_cpi <- read.csv("data/CPIAUCSL.csv")
cpi  <- ts(raw_cpi$CPIAUCSL, start = c(1947, 1), frequency = 12)
infl <- yoy(cpi)
jobs <- yoy(pay)
ip   <- yoy(fred("INDPRO"))
gdp  <- yoy(fred("GDPC1"))

#| **Label each panel with its latest reading,** computed from the data, so the chart updates itself whenever the data do. `k` is the position of the last non-missing value: CPI inflation for October 2026 is `NA`, because it would need the missing October 2025 price level. `ts_dates()` is a course helper that returns each observation's date as text.
latest <- function(name, x, unit) {
  k <- max(which(!is.na(x)))
  when <- as.Date(ts_dates(x)[k])
  when <- if (frequency(x) == 4) paste0(format(when, "%Y"), " Q", cycle(x)[k]) else format(when, "%b %Y")
  sprintf("%s: %.1f%s in %s", name, x[k], unit, when)
}
labels <- c(latest("Unemployment rate", unrate, "%"),
            latest("CPI inflation, y/y", infl, "%"),
            latest("Payroll jobs, y/y", jobs, "%"),
            latest("Industrial production, y/y", ip, "%"),
            latest("Real GDP, y/y", gdp, "%"))
labels

#| **The economy at a glance.** One small panel per series, with gray bands for NBER recessions (`recessions = TRUE`). Notice how all five react to the 2008 and 2020 recessions, and how differently each one moves. GDP is quarterly while the others are monthly; small multiples let you compare them without forcing them onto one axis.
panels <- lapply(list(unrate, infl, jobs, ip, gdp), window, start = 2000)
do.call(viz_ts, c(setNames(panels, labels),
                  list(facet = TRUE, recessions = TRUE,
                       title = "The U.S. economy at a glance, 2000 to today")))
