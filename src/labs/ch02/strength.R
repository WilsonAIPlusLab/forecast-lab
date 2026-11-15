#| **Eight retail categories, all NSA.** These are Census monthly retail trade series by NAICS code, in $ millions, not seasonally adjusted. A named vector lets us loop over them and keep readable labels.
ids <- c(Clothing = "MRTSSM448USN", Electronics = "MRTSSM443USN",   # name = label, value = FRED series ID
         `General merchandise` = "MRTSSM452USN", `Building materials` = "MRTSSM444USN",
         `E-commerce` = "MRTSSM4541USN", Grocery = "MRTSSM445USN",
         `Gas stations` = "MRTSSM447USN", Restaurants = "MRTSSM722USN")

#| **Seasonal strength, Hyndman's $F_S$.** Decompose with STL (logs, robust), then compare the variance of the remainder with the variance of seasonal + remainder:
#| - $F_S = \max(0,\ 1 - \text{Var}(R) / \text{Var}(S + R))$
#| - Near 1: the seasonal pattern dominates the month-to-month wiggles. Near 0: there is barely any seasonality.
strength <- function(x) {                     # seasonal strength F_S of one series, between 0 and 1
  f <- stl(log(x), s.window = 13, robust = TRUE)   # robust STL on log sales
  s <- f$time.series[, "seasonal"]; r <- f$time.series[, "remainder"]   # seasonal (S) and remainder (R) columns
  max(0, 1 - var(r) / var(s + r))             # the formula above; the last line is the return value
}

#| **Peak month.** The seasonal component of 2025, the most recent full year, tells us which month each category lives for.
peak <- function(x) {                         # name of the month with the largest seasonal effect in 2025
  s <- stl(log(x), s.window = 13, robust = TRUE)$time.series[, "seasonal"]
  month.abb[which.max(window(s, start = c(2025, 1), end = c(2025, 12)))]   # which.max() = position of the biggest value
}

#| **Run it for every category, twice.** `sapply()` applies a function to each series. First on 2010–2019 (before COVID), then on everything from 2010 to the latest month.
pre  <- lapply(ids, fred, start = 2010, end = c(2019, 12))   # lapply() calls fred() on each ID: a list of 8 series, 2010-2019
full <- lapply(ids, fred, start = 2010)       # same 8 series, 2010 to the latest month
tab <- data.frame(pre_covid = round(sapply(pre, strength), 3),   # sapply() = lapply() that simplifies to a vector
                  with_covid = round(sapply(full, strength), 3),
                  peak = sapply(full, peak))
tab <- tab[order(-tab$pre_covid), ]           # sort rows by pre-COVID strength, largest first
tab

#| **Rank them (pre-COVID).** In normal times almost every store type is strongly seasonal, but in different months. Now look back at the table: adding 2020 onward drags clothing from about 0.99 to about 0.5. Robust STL put the lockdown collapse in the remainder, and $F_S$ is a variance ratio, so one giant shock can swamp a perfectly regular pattern.
viz_bars(tab$pre_covid, labels = rownames(tab),   # one bar per category
         title = "Before COVID, nearly every kind of store was strongly seasonal",
         subtitle = "Seasonal strength F_S from STL on logs (0 = none, 1 = pure seasonality), NSA, 2010–2019",
         highlight = c("Clothing", "Gas stations"))   # bars drawn in a highlight color
