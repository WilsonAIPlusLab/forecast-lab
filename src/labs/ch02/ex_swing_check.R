# Hidden check for ex_swing: recompute the December gaps and compare.
.d <- decompose(ecom); .p <- (100 * (ecom / .d$trend - 1))[cycle(ecom) == 12]; .u <- (ecom - .d$trend)[cycle(ecom) == 12]
.ok1 <- exists("gap_pct") && length(gap_pct) == length(ecom) && isTRUE(all.equal(as.numeric(gap_pct), as.numeric(100 * (ecom / .d$trend - 1))))
.ok2 <- exists("dec_dollars") && length(dec_dollars) == 20 && isTRUE(all.equal(as.numeric(dec_dollars), as.numeric(.u)))
.ok3 <- exists("multiplicative") && isTRUE(multiplicative)
check_that(.ok1 && .ok2 && .ok3,
  sprintf("December's boost grew from $%.1fbn (2000) to $%.1fbn (2017) as the business grew, but in percent it stayed in the same range (%+.0f%% vs %+.0f%%). Single years wobble (2018 is low), so judge the overall pattern, not one row. That is multiplicative seasonality: model log(sales), and every seasonal effect becomes a constant percentage.", .u[1] / 1000, .u[18] / 1000, .p[1], .p[18]),
  if (!.ok1) "Step 1: percent above trend is 100 * (data / trend - 1), and the trend is stored in `dec$trend`." else if (!.ok2) "Step 2: December is month number 12, so keep the rows where `cycle(ecom) == 12`." else "Step 3: look at the table. The dollar column grows a lot; the percent column does not. Which kind of seasonality is that? Answer TRUE or FALSE (no quotes).")
