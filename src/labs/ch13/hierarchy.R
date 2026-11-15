#| **A real hierarchy.** Census publishes total retail and food services sales (`RSAFS`), split into motor vehicles & parts (`RSMVPD`) and everything else (`RSFSXMV`). We split "everything else" into nine published categories plus **Other**: grocery stores, sporting goods and miscellaneous stores, which aren't bundled here. Other is defined as the remainder, so the tree adds up exactly. All series are seasonally adjusted, in $ millions per month.
library(forecast)
cats <- c(Food_services = "RSFSDP", Gas = "RSGASS", Clothing = "RSCCAS", Building = "RSDBS",
          Health = "RSHPCS", Nonstore = "RSNSR", General = "RSGMS", Furniture = "RSFHFS", Electronics = "RSEAS")
bottom <- lapply(cats, fred, start = 2015)
ex_autos <- fred("RSFSXMV", start = 2015)
bottom$Other <- ex_autos - Reduce(`+`, bottom)
bottom <- c(list(Motor_vehicles = fred("RSMVPD", start = 2015)), bottom)
all <- cbind(fred("RSAFS", start = 2015), ex_autos, do.call(cbind, bottom))
colnames(all) <- c("Total", "Ex_autos", names(bottom))
dim(all)

#| **The summing matrix S** encodes the tree: each row says which bottom-level series add up to that node. Total = all 11, Ex-autos = the 10 non-auto categories, and each bottom series is itself. Any **coherent** set of forecasts can be written as S × (bottom-level forecasts).
S <- rbind(Total = rep(1, 11), Ex_autos = c(0, rep(1, 10)), diag(11))
rownames(S)[-(1:2)] <- colnames(S) <- names(bottom)
S[1:3, ]

#| **Forecast all 13 series in a loop** (one line, thanks to `sapply`). Hold out the last 12 months. `ets(model = "ZZN")` lets R choose the error and trend type for each series, with no seasonal component because the data are already seasonally adjusted. These independent **base forecasts** are *incoherent*: the Total forecast does not equal the sum of its parts.
h <- 12; n <- nrow(all)
train <- window(all, end = time(all)[n - h])
test  <- window(all, start = time(all)[n - h + 1])
base <- sapply(colnames(all), function(s) forecast(ets(train[, s], model = "ZZN"), h = h)$mean)
round(base[1:3, "Total"] - rowSums(base[1:3, names(bottom)]))   # incoherence, $ millions

#| **Three ways to make them add up.**
#| - **Bottom-up**: forecast the 11 bottom series, then add. In matrix form: S × bottom.
#| - **Top-down**: forecast the total, then split it using each category's average share over the last 12 months.
#| - **Reconciliation**: adjust *all* base forecasts as little as possible so they add up. OLS reconciliation is ỹ = S(S′S)⁻¹S′ŷ. WLS uses weights W = diag(S·1), so nodes made of many series get more room to move. MinT goes further and estimates the full error covariance matrix (`forecast::` doesn't include it; the `fable` and `hts` packages do).
bu <- t(S %*% t(base[, names(bottom)]))
share <- colMeans(tail(train[, names(bottom)], 12) / as.numeric(tail(train[, "Total"], 12)))
td <- t(S %*% t(outer(base[, "Total"], share)))
reconcile <- function(W) S %*% solve(t(S) %*% solve(W) %*% S) %*% t(S) %*% solve(W)
ols <- t(reconcile(diag(13)) %*% t(base))
wls <- t(reconcile(diag(rowSums(S))) %*% t(base))
colnames(ols) <- colnames(wls) <- colnames(base)

#| **Score every method at every level** with MAPE (%) over the 12 test months. Bottom-up wins at the top: adding up the 11 category forecasts tracked total sales better than the total's own model did. OLS spreads the total's large error evenly, and that hurts small series like electronics. WLS is a middle ground. One 12-month test window is a single draw, so treat the ranking as suggestive, not settled.
mape <- function(f) setNames(100 * colMeans(abs(test - f) / test), colnames(all))
scores <- rbind(Base = mape(base), `Bottom-up` = mape(bu), `Top-down` = mape(td), OLS = mape(ols), WLS = mape(wls))
summary_tab <- data.frame(Total = scores[, "Total"], `Ex-autos` = scores[, "Ex_autos"],
                          `Avg of 11 categories` = rowMeans(scores[, names(bottom)]),
                          `Adds up?` = c("No", "Yes", "Yes", "Yes", "Yes"), check.names = FALSE)
viz_table(summary_tab, highlight = c("Total", "Ex-autos", "Avg of 11 categories"), digits = 2,
          title = "Bottom-up gives the best total here; only Base is incoherent")
summary_tab
