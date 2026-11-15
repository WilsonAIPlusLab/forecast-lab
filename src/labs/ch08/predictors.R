#| **Gather three more candidate predictors**, all monthly averages:
#| - `baa`: Moody's Baa corporate yield minus the 10-year Treasury (pct. points), a measure of credit stress.
#| - `claims`: the 12-month % change in initial jobless claims (SA). Layoffs show up here first.
#| - `sent`: University of Michigan consumer sentiment (index, NSA). It is monthly only since 1978, which is why the bundled series starts then.
#| The credit spread starts in 1986, so this comparison runs from 1986.
baa <- fred("BAA10Y", to = "month", start = 1986)
icsa <- fred("ICSA", to = "month")
claims <- window(100 * log(icsa / stats::lag(icsa, -12)), start = 1986)
sent <- fred("UMCSENT", start = 1986)

#| **Line everything up by month** with `ts.intersect`, then add the recession indicator at two horizons: 12 months ahead (as before) and **3 months ahead**, so we can ask whether the answer depends on the horizon.
Z <- ts.intersect(spread = window(spread, start = 1986), baa, claims, sent, rec = window(rec, start = 1986))
z <- data.frame(date = as.Date(ts_dates(Z)), as.matrix(Z))
n <- nrow(z)
z$ahead12 <- c(z$rec[-(1:12)], rep(NA, 12))
z$ahead3  <- c(z$rec[-(1:3)], rep(NA, 3))
range(z$date)

#| **Train through 2005, test from 2006.** The training period holds two recessions (1990–91 and 2001); the test period holds 2008–09 and 2020. For each horizon and each set of predictors, fit a logit on the training months and record the out-of-sample AUC.
auc <- function(p, y) { r <- rank(p); n1 <- sum(y == 1); n0 <- sum(y == 0); (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0) }
oos_auc <- function(target, rhs) {
  f <- as.formula(paste(target, "~", rhs))
  tr <- z[z$date <= as.Date("2005-12-01") & !is.na(z[[target]]), ]
  te <- z[z$date >= as.Date("2006-01-01") & !is.na(z[[target]]), ]
  m <- glm(f, data = tr, family = binomial)
  auc(predict(m, te, type = "response"), te[[target]])
}
models <- c(`Spread only` = "spread", `+ credit spread` = "spread + baa", `+ jobless claims` = "spread + claims",
            `+ sentiment` = "spread + sent", `All four` = "spread + baa + claims + sent")
res <- data.frame(`3 months ahead` = sapply(models, oos_auc, target = "ahead3"),
                  `12 months ahead` = sapply(models, oos_auc, target = "ahead12"), check.names = FALSE)
round(res, 3)

#| **Read the table by column.** Higher AUC is better.
#| - **Three months out**, the spread alone does *worse than a coin flip* (AUC below 0.5): the curve usually steepens again just before a recession, as the Fed starts cutting. Jobless claims transform the model.
#| - **Twelve months out**, adding predictors barely changes the AUC.
#| This matches Estrella and Mishkin (1998): other indicators help at short horizons, while the yield curve dominates beyond a couple of quarters.
viz_table(res, highlight = c("3 months ahead", "12 months ahead"), lower_is_better = FALSE, digits = 3,
          title = "Claims help for the next quarter; a year out, extra predictors barely move the needle")
