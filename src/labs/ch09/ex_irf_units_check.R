# Hidden check for ex_irf_units: recompute the answer and compare.
.r <- irf(VAR(y, p = 4, type = "const"), impulse = "ffr", n.ahead = 20, ortho = TRUE, boot = FALSE)$irf$ffr
.u <- .r[, "unemp"] / .r[1, "ffr"]
.ok_size <- exists("unemp_1pp") && length(unemp_1pp) == 21 && isTRUE(all.equal(as.numeric(unemp_1pp), as.numeric(.u)))
check_that(.ok_size && exists("at8") && isTRUE(abs(at8 - .u[9]) < 1e-9) && exists("peak_q") && isTRUE(peak_q == which.max(.u) - 1),
  sprintf("Your sentence for the CFO: \"A 1-percentage-point surprise rise in the funds rate is followed by an unemployment rate about %.2f points higher two years later than it would otherwise have been, with the peak %d quarters after the hike.\" The VAR's own shock was %.2f pp, so every number in the chapter's charts is %.2f times the numbers here. Responses are linear: a 25-basis-point surprise would move unemployment by a quarter as much, about %.3f points.",
          .u[9], which.max(.u) - 1, .r[1, "ffr"], .r[1, "ffr"], .u[9] / 4),
  if (!.ok_size) "Step 1: divide the whole unemployment response by size, the funds rate's own jump on impact (about 0.76 pp). Then each number is \"per 1 pp of surprise\"." else
  "Row 1 of an irf() table is h = 0 (the shock quarter), so h = 8 is row 9, and the row number from which.max() minus 1 gives quarters after the hike.")
