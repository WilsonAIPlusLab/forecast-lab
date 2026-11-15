#| **Open the raw file first.** Every bundled series is a plain CSV downloaded from FRED: one column of dates, one column of values. `read.csv()` gives you a *data frame*. Look at `str()`: the date column arrives as **text** (`chr`), so R has no idea yet that this is a time series.
raw <- read.csv("data/UNRATE.csv")            # unemployment rate (%), monthly, as a data frame
head(raw, 3)                                  # first 3 rows
str(raw)                                      # structure: column names and types

#| **Turn the column into a `ts` object.** A `ts` stores the values plus two facts: when the series **starts** and how many observations make one year (its **frequency**: 12 for monthly, 4 for quarterly, 1 for annual). From those two facts R can work out the date of every observation.
unrate <- ts(raw$UNRATE, start = c(1948, 1), frequency = 12)   # $ picks a column; monthly ts from January 1948

#| **Ask the series about itself.** `start()` and `end()` return *(year, period)* pairs, so `2026 10` means October 2026. `time()` gives each observation's date as a decimal year: January is `.000`, February `.083` (1/12), and so on. Get in the habit of running these four lines on every new series.
start(unrate)                                 # first (year, month)
end(unrate)                                   # last (year, month)
frequency(unrate)                             # observations per year
tail(time(unrate), 3)                         # dates of the last 3 observations, as decimal years

#| **Cut out a time window.** `window()` subsets by date, not by row number, so you never have to count rows. Here: January 2019 through December 2021, which spans the COVID spike to 14.8% in April 2020.
covid <- window(unrate, start = c(2019, 1), end = c(2021, 12))   # Jan 2019 to Dec 2021
covid                                         # print it as a year-by-month table

#| **A month that does not exist.** One value in this file is blank, so `read.csv()` stored it as `NA`. It is **October 2025**: the federal government shut down from October 1 to November 12, 2025, and the Census Bureau interviewers who run the household survey never collected that month. It will never be filled in. Keep the `NA` in place: a `ts` assumes evenly spaced observations, so deleting the row would silently shift every later value one month earlier.
raw[is.na(raw$UNRATE), ]                      # [rows, ]: show the rows whose value is missing
window(unrate, start = c(2025, 8), end = c(2025, 12))   # Aug to Dec 2025: the NA sits in October

#| **`fred()` does the loading in one line.** It reads the CSV, detects the frequency from the date spacing, and returns a `ts`. On payroll jobs (no gaps) the hand-built series and the `fred()` series are identical. On a series with a short gap, such as `UNRATE`, `fred()` prints a **Note** and fills the missing month by *linear interpolation* (the average of its neighbors), because most models cannot handle `NA`. That is convenient for modeling, but the filled value is an estimate, not published data. When you need to know what was actually published, read the CSV as above.
raw_pay <- read.csv("data/PAYEMS.csv")        # payroll employment, thousands of jobs
pay <- ts(raw_pay$PAYEMS, start = c(1939, 1), frequency = 12)   # build the ts by hand
all.equal(pay, fred("PAYEMS"))                # TRUE: identical to fred()'s version
window(fred("UNRATE"), start = c(2025, 8), end = c(2025, 12))   # fred() fills October 2025 by interpolation

#| **Five vital signs of the economy.** We put each series in the form analysts quote it: the unemployment *rate* as a level, and the other four as **percent change from a year earlier**. `stats::lag(x, -12)` shifts a monthly series back 12 months, and R lines the two up by date before dividing. GDP is quarterly, so its year-ago lag is 4. CPI has the same October 2025 gap as unemployment, so we build it from its CSV too: we do not want an inflation rate that rests on an interpolated month.
yoy <- function(x) 100 * (x / stats::lag(x, -frequency(x)) - 1)   # % change from one year earlier (lag 12 monthly, 4 quarterly)
raw_cpi <- read.csv("data/CPIAUCSL.csv")      # consumer price index, keeps the October 2025 gap
cpi  <- ts(raw_cpi$CPIAUCSL, start = c(1947, 1), frequency = 12)
infl <- yoy(cpi)                              # CPI inflation, % y/y
jobs <- yoy(pay)                              # payroll job growth, % y/y
ip   <- yoy(fred("INDPRO"))                   # industrial production growth, % y/y
gdp  <- yoy(fred("GDPC1"))                    # real GDP growth (quarterly), % y/y

#| **Label each panel with its latest reading,** computed from the data, so the chart updates itself whenever the data do. `k` is the position of the last non-missing value: CPI inflation for October 2026 is `NA`, because it would need the missing October 2025 price level. `ts_dates()` is a course helper that returns each observation's date as text.
latest <- function(name, x, unit) {           # builds a label like "Name: 4.3% in Sep 2026"
  k <- max(which(!is.na(x)))                  # position of the last non-missing value
  when <- as.Date(ts_dates(x)[k])             # its date
  # quarterly series: "2026 Q2" (cycle() gives the quarter number); monthly: "Sep 2026"
  when <- if (frequency(x) == 4) paste0(format(when, "%Y"), " Q", cycle(x)[k]) else format(when, "%b %Y")
  sprintf("%s: %.1f%s in %s", name, x[k], unit, when)   # fill the template; %.1f = one decimal
}
labels <- c(latest("Unemployment rate", unrate, "%"),   # one label per series
            latest("CPI inflation, y/y", infl, "%"),
            latest("Payroll jobs, y/y", jobs, "%"),
            latest("Industrial production, y/y", ip, "%"),
            latest("Real GDP, y/y", gdp, "%"))
labels

#| **The economy at a glance.** One small panel per series, with gray bands for NBER recessions (`recessions = TRUE`). Notice how all five react to the 2008 and 2020 recessions, and how differently each one moves. GDP is quarterly while the others are monthly; small multiples let you compare them without forcing them onto one axis.
panels <- lapply(list(unrate, infl, jobs, ip, gdp), window, start = 2000)   # lapply() runs window() on each series
# do.call() calls viz_ts with the list's items as its arguments; setNames() names each panel with its label
do.call(viz_ts, c(setNames(panels, labels),
                  list(facet = TRUE, recessions = TRUE,   # facet = one small panel per series
                       title = "The U.S. economy at a glance, 2000 to today")))
