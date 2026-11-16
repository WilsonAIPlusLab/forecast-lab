# Hidden check for ex_price_level: recompute the answer and compare.
.r <- irf(VAR(y, p = 4, type = "const"), impulse = "ffr", n.ahead = 20, ortho = TRUE, boot = FALSE)$irf$ffr
.pl <- cumsum(.r[, "infl"] / .r[1, "ffr"]) / 4
.ok_cum <- exists("cum_infl") && length(cum_infl) == 21 && isTRUE(all.equal(as.numeric(cum_infl), as.numeric(4 * .pl)))
.ok_pl <- exists("price_1pp") && length(price_1pp) == 21 && isTRUE(all.equal(as.numeric(price_1pp), as.numeric(.pl)))
check_that(.ok_pl && exists("price12") && isTRUE(abs(price12 - .pl[13]) < 1e-9),
  sprintf("Two quarters after a 1-pp surprise hike the CPI is about %+.2f%% versus no hike (the price puzzle, now in the price level); three years after, it is about %+.2f%%. Notice how small both numbers are: the inflation response looked like a quarter-point swing, but in the level it is about a tenth of a percent, and the chapter's 90%% band for this path includes zero from the third quarter on. A growth-rate response and a level response answer different questions, so say which one you report.",
          .pl[3], .pl[13]),
  if (!.ok_cum) "Step 1 needs running totals of infl_1pp: R's cumsum() function." else if (!.ok_pl)
    "Step 2: the inflation series is 400 x the quarterly log change, so a summed annualized rate must be divided by 4 to become a % change in the price level." else
    "Row 1 is h = 0, so h = 12 is row 13.")
