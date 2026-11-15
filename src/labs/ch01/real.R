#| **Two ingredients.** Nominal retail and food services sales (`RSAFS`, $ millions, seasonally adjusted) and the consumer price index (`CPIAUCSL`, index 1982–84 = 100, seasonally adjusted). We build CPI from its CSV so that the missing October 2025 stays in place as `NA` (`fred()` would fill it by interpolation, which is fine for modeling but would invent one month of real sales).
nominal <- fred("RSAFS")                      # nominal retail & food services sales, $ millions, SA
raw_cpi <- read.csv("data/CPIAUCSL.csv")      # CPI from the raw file, keeps the October 2025 NA
cpi <- ts(raw_cpi$CPIAUCSL, start = c(1947, 1), frequency = 12)   # monthly ts from January 1947

#| **Deflate: divide by the price index.** $\text{real}_t = \text{nominal}_t / \text{CPI}_t \times 100$. Because CPI averages 100 in 1982–84, the result is in *1982–84 dollars*: what this month's spending would have cost at 1982–84 prices. R aligns the two series by date before dividing (CPI starts in 1947, sales in 1992, so the result starts in 1992).
real <- nominal / cpi * 100                   # real sales in 1982-84 dollars (R matches months by date)
start(real)                                   # first month where both series exist

#| **Check against FRED's own real series.** FRED publishes exactly this calculation as `RRSFS`. Through 2024 the two agree (the tiny tolerance allows for rounding in the published file). Rebuilding a published number yourself is the best way to be sure you understand it.
all.equal(as.numeric(window(real, end = c(2024, 12))),   # our series through 2024, as plain numbers
          as.numeric(window(fred("RRSFS"), end = c(2024, 12))), tolerance = 1e-5)   # vs FRED's; TRUE = they agree

#| **How much of the growth is real?** Compare the latest month (September 2026) with the 2019 average. Nominal sales grew a lot more than real sales; the difference is inflation.
# % change from the 2019 average to September 2026
growth <- function(x) 100 * (window(x, start = c(2026, 9), end = c(2026, 9)) /
                             mean(window(x, start = c(2019, 1), end = c(2019, 12))) - 1)
g <- c(nominal = growth(nominal), prices = growth(cpi), real = growth(real))   # named vector of three growth rates
round(g, 1)                                   # in percent, one decimal

#| **Growth rates multiply, they do not subtract.** $(1 + \text{nominal}) = (1 + \text{real}) \times (1 + \text{inflation})$. Subtracting (nominal minus inflation) is a fine shortcut for small rates, but over several years of inflation it overstates real growth by a few points.
# g[["nominal"]] extracts one value by name; exact = divide growth factors, shortcut = subtract rates
round(c(exact = 100 * ((1 + g[["nominal"]] / 100) / (1 + g[["prices"]] / 100) - 1),
        shortcut = g[["nominal"]] - g[["prices"]]), 1)

#| **Express real sales in today's dollars.** 1982–84 dollars are hard to picture. Multiply by the latest CPI so that the most recent month's real and nominal values coincide; growth rates are unchanged.
cpi_now <- window(cpi, start = c(2026, 9), end = c(2026, 9))   # CPI in September 2026
real_now <- real * as.numeric(cpi_now) / 100  # real sales in September-2026 dollars

#| **Index both to 2019 = 100 and plot.** The gap that opens after 2021 is the inflation surge: households paid much more, but bought only modestly more stuff.
base <- function(x) 100 * x / mean(window(x, start = c(2019, 1), end = c(2019, 12)))   # rescale so 2019 average = 100
viz_ts(Nominal = base(window(nominal, start = 2015)), Real = base(window(real_now, start = 2015)),   # both from 2015 on
       ylab = "index, 2019 average = 100",
       title = "Retail sales are up sharply since 2019, but mostly because prices are")
