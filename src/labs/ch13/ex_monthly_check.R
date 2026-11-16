# Hidden grader: recomputes the monthly average (flow) and the end-of-month value (stock).
.a <- aggregate(ICSA ~ month, data = ic, FUN = mean)
.e <- aggregate(CCSA ~ month, data = cc, FUN = function(x) tail(x, 1))
.s <- aggregate(ICSA ~ month, data = ic, FUN = sum)
.ok1 <- exists("ic_m") && is.data.frame(ic_m) && nrow(ic_m) == nrow(.a) && isTRUE(all.equal(ic_m$ICSA, .a$ICSA))
.ok2 <- exists("cc_m") && is.data.frame(cc_m) && nrow(cc_m) == nrow(.e) && isTRUE(all.equal(cc_m$CCSA, .e$CCSA))
.g <- function(d, m) d$ICSA[d$month == m] / 1000
check_that(.ok1 && .ok2,
  sprintf("Right. October 2026 averaged %.1fk initial claims a week, down from %.1fk in September. The monthly sum says the opposite: %.0fk vs %.0fk, up %.0f%%, only because October has five week-ending Saturdays and September has four. Continuing claims at the end of October: %sk people on benefits.",
          .g(.a, "2026-10"), .g(.a, "2026-09"), .g(.s, "2026-10"), .g(.s, "2026-09"),
          100 * (.g(.s, "2026-10") / .g(.s, "2026-09") - 1), format(round(tail(.e$CCSA, 1) / 1000), big.mark = ",")),
  if (!.ok1) "Initial claims are a flow: summarize each month by its average week (FUN = mean)." else
    "Continuing claims are a stock: keep the end-of-month value with the helper defined at the top (FUN = last_value).")
