#| **Two ways to forecast 12 months ahead.** *Recursive*: one model for next month, fed its own forecasts to go further. *Direct*: a separate model for each horizon h = 1…12, each trained to jump straight from what is known today to month h. We compare them on retail sales growth (NSA) from three year-end origins: December 2022, 2023 and 2024.
library(randomForest)
retail <- fred("RSXFSN", start = 2010)        # monthly retail sales, $ millions, not seasonally adjusted
lag_k  <- function(x, k) c(rep(NA, k), head(x, -k))   # shift x down k places (NA on top)

#| **The direct table for horizon h.** The target is growth in month *s*; the features are growth at the origin (`a1` = month *s − h*, `a2` = month *s − h − 1*), growth in the same month last year (`g12`, known as long as h ≤ 12) and the target's calendar month. For h = 1 this is exactly the recursive model's table.
direct_table <- function(g, h) {
  x <- as.numeric(g)
  data.frame(g = x, a1 = lag_k(x, h), a2 = lag_k(x, h + 1), g12 = lag_k(x, 12),   # features lagged by h, h+1, 12
             month = factor(cycle(g), levels = 1:12))   # target's calendar month, as a category
}

#| **Run both strategies from one origin.** Both use 200 trees and `mtry = 2`. The recursive loop predicts a month, appends it to the growth history and repeats. The direct loop fits 12 forests and asks each one a single question. Both turn growth back into dollars with `last level × exp(cumsum(growth) / 100)`.
both_ways <- function(origin_year) {
  y <- window(retail, end = c(origin_year, 12))   # data up to December of the origin year
  g <- 100 * diff(log(y)); x <- as.numeric(g); n <- length(x)   # growth (%), as a plain vector of length n
  set.seed(1)
  # recursive: one 1-step model ...
  rec_model <- randomForest(g ~ a1 + a2 + g12 + month, data = na.omit(direct_table(g, 1)), ntree = 200, mtry = 2)
  gr <- x
  for (h in 1:12) {                           # ... fed its own forecasts, 12 times
    k <- length(gr)
    gr <- c(gr, predict(rec_model, data.frame(a1 = gr[k], a2 = gr[k - 1], g12 = gr[k - 11],
                                              month = factor(h, levels = 1:12))))   # month h = Jan, Feb, ...
  }
  # direct: for each horizon h, a separate forest that jumps straight from the origin to month h
  g_dir <- sapply(1:12, function(h) {
    set.seed(1)
    m <- randomForest(g ~ a1 + a2 + g12 + month, data = na.omit(direct_table(g, h)), ntree = 200, mtry = 2)
    predict(m, data.frame(a1 = x[n], a2 = x[n - 1], g12 = x[n + h - 12], month = factor(h, levels = 1:12)))
  })
  last   <- as.numeric(tail(y, 1))            # last observed level at the origin
  actual <- as.numeric(window(retail, start = c(origin_year + 1, 1), end = c(origin_year + 1, 12)))   # next 12 months
  # absolute errors per horizon, after compounding growth back into dollars; cbind = side-by-side columns
  cbind(recursive = abs(actual - last * exp(cumsum(tail(gr, 12)) / 100)),
        direct    = abs(actual - last * exp(cumsum(g_dir) / 100)))
}

#| **Average the absolute errors over the three origins**, horizon by horizon (rows = months ahead, $ millions). At 1 month ahead the two are identical: it is the same model, with the same seed.
errs <- lapply(2022:2024, both_ways)          # lapply: run both_ways for each origin, keep a list of results
mae_h <- Reduce(`+`, errs) / length(errs)     # add the three 12 x 2 tables together, then average
rownames(mae_h) <- paste(1:12, "mo")          # label rows "1 mo", "2 mo", ...
round(mae_h)

#| **Error by horizon.** Neither strategy wins at every horizon. Recursive errors can snowball because each forecast feeds the next; direct models avoid that, but each one learns from staler clues and fewer rows. Averaged over all 12 horizons (printed below the chart), recursive comes out ahead on this series, by about 2,000 ($ millions).
viz_lines(1:12, Recursive = mae_h[, "recursive"], Direct = mae_h[, "direct"], xlab = "months ahead",
          ylab = "MAE ($ millions)", zero = TRUE, title = "Recursive vs direct: error by horizon, three origins")
round(colMeans(mae_h))                        # average MAE over all 12 horizons
