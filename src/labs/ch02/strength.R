#| **Eight retail categories, all NSA.** These are Census monthly retail trade series by NAICS code, in $ millions, not seasonally adjusted. A named vector lets us loop over them and keep readable labels.
ids <- c(Clothing = "MRTSSM448USN", Electronics = "MRTSSM443USN",
         `General merchandise` = "MRTSSM452USN", `Building materials` = "MRTSSM444USN",
         `E-commerce` = "MRTSSM4541USN", Grocery = "MRTSSM445USN",
         `Gas stations` = "MRTSSM447USN", Restaurants = "MRTSSM722USN")

#| **Seasonal strength, Hyndman's $F_S$.** Decompose with STL (logs, robust), then compare the variance of the remainder with the variance of seasonal + remainder:
#| - $F_S = \max(0,\ 1 - \text{Var}(R) / \text{Var}(S + R))$
#| - Near 1: the seasonal pattern dominates the month-to-month wiggles. Near 0: there is barely any seasonality.
strength <- function(x) {
  f <- stl(log(x), s.window = 13, robust = TRUE)
  s <- f$time.series[, "seasonal"]; r <- f$time.series[, "remainder"]
  max(0, 1 - var(r) / var(s + r))
}

#| **Peak month.** The seasonal component of 2025, the most recent full year, tells us which month each category lives for.
peak <- function(x) {
  s <- stl(log(x), s.window = 13, robust = TRUE)$time.series[, "seasonal"]
  month.abb[which.max(window(s, start = c(2025, 1), end = c(2025, 12)))]
}

#| **Run it for every category, twice.** `sapply()` applies a function to each series. First on 2010–2019 (before COVID), then on everything from 2010 to the latest month.
pre  <- lapply(ids, fred, start = 2010, end = c(2019, 12))
full <- lapply(ids, fred, start = 2010)
tab <- data.frame(pre_covid = round(sapply(pre, strength), 3),
                  with_covid = round(sapply(full, strength), 3),
                  peak = sapply(full, peak))
tab <- tab[order(-tab$pre_covid), ]
tab

#| **Rank them (pre-COVID).** In normal times almost every store type is strongly seasonal, but in different months. Now look back at the table: adding 2020 onward drags clothing from about 0.99 to about 0.5. Robust STL put the lockdown collapse in the remainder, and $F_S$ is a variance ratio, so one giant shock can swamp a perfectly regular pattern.
viz_bars(tab$pre_covid, labels = rownames(tab),
         title = "Before COVID, nearly every kind of store was strongly seasonal",
         subtitle = "Seasonal strength F_S from STL on logs (0 = none, 1 = pure seasonality), NSA, 2010–2019",
         highlight = c("Clothing", "Gas stations"))
