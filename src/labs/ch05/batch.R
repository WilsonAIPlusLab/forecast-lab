#| **The product list.** In a real company this would be 500 SKUs pulled from a database. Here it is 14 U.S. retail categories from the Census Bureau's monthly retail survey (NAICS codes, $ millions, **not seasonally adjusted**). E-commerce (4541) is a part of nonstore retailers (454), so those two move together.
library(forecast)
cats <- c("441" = "Motor vehicles & parts", "442" = "Furniture", "443" = "Electronics & appliances",
          "444" = "Building materials", "445" = "Food & beverage stores", "446" = "Health & personal care",
          "447" = "Gasoline stations", "448" = "Clothing", "451" = "Sporting goods & hobby",
          "452" = "General merchandise", "453" = "Misc. store retailers", "454" = "Nonstore retailers",
          "4541" = "E-commerce", "722" = "Food services & drinking")

#| **One function that does the whole job for one series.** This is the heart of batch forecasting: write the recipe once, test it on one series, then apply it to all of them.
#| - **Backtest:** fit ETS on data through Aug 2025, forecast the 12 held-out months, and record MASE.
#| - **Production forecast:** re-run the chosen model, with the same parameters, through *all* the data (`use.initial.values = TRUE`, so nothing is re-estimated) and forecast the next 12 months.
#| - `model = "ZZM"` lets `ets()` choose the error and trend types but fixes **multiplicative seasonality**, which suits sales whose seasonal swings grow with the business. It also cuts the search from 15 candidate models to 3, which keeps 14 fits fast in your browser. Real planning systems make the same speed-versus-search trade-off.
run_one <- function(code) {
  y     <- fred(paste0("MRTSSM", code, "USN"), start = 2015)
  train <- window(y, end = c(2025, 8)); test <- window(y, start = c(2025, 9))
  fit   <- ets(train, model = "ZZM")
  acc   <- accuracy(forecast(fit, h = 12), test)["Test set", ]
  final <- forecast(ets(y, model = fit, use.initial.values = TRUE), h = 12)   # same model, same parameters, all data
  list(code = code, name = unname(cats[code]), model = fit$method,
       MAPE = acc[["MAPE"]], MASE = acc[["MASE"]], y = y, fc = final)
}

#| **The Monday-morning loop.** `lapply()` runs the recipe on every category and collects the results in a list. On 500 products you would run exactly this line, just on a bigger list.
results <- lapply(names(cats), run_one)
length(results)

#| **Build the exception report.** One row per category, sorted worst-first by backtest MASE, with a traffic-light status. A planner reads only the top of this table: the green rows can go straight to the supply team.
report <- data.frame(Category = sapply(results, `[[`, "name"),
                     Model    = sapply(results, `[[`, "model"),
                     MAPE     = sapply(results, `[[`, "MAPE"),
                     MASE     = sapply(results, `[[`, "MASE"))
report$Status <- ifelse(report$MASE > 1, "Review", ifelse(report$MASE > 0.8, "Watch", "OK"))
report <- report[order(-report$MASE), ]
rownames(report) <- NULL
viz_table(report, digits = 2, title = "Exception report: categories sorted by backtest MASE (worst first)")

#| **The same report as a chart.** Bars above 1 mean the ETS forecast missed by more than seasonal naive typically does in-sample. These are the categories a human should look at before the forecast goes out.
viz_bars(setNames(report$MASE, report$Category), xlab = "backtest MASE (12 months to Aug 2026)",
         highlight = report$Category[report$Status == "Review"],
         title = "Four categories need a human look before the forecast ships")

#| **Small multiples of every forecast.** One panel per category, with the next 12 months and an 80% interval, labelled by status. This is the one-page view a demand-planning meeting starts from.
viz_custom("ch05-multiples", title = "Next 12 months, every category", source = "FRED, Federal Reserve Bank of St. Louis (MRTSSM441USN … MRTSSM722USN)",
  panels = lapply(results, function(r) list(
    name = r$name, model = r$model, mase = r$MASE,
    date = ts_dates(window(r$y, start = 2022)), value = as.numeric(window(r$y, start = 2022)),
    fdate = ts_dates(r$fc$mean), mean = as.numeric(r$fc$mean),
    lo = as.numeric(r$fc$lower[, "80%"]), hi = as.numeric(r$fc$upper[, "80%"]))))
