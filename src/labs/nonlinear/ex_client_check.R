# Hidden check for ex_client: recomputes the answers and writes the manager's memo.
.m <- glm(yes ~ age + contact + campaign + poutcome + euribor3m, family = binomial, data = train)
.h <- data.frame(age = 40, contact = "cellular", campaign = 1, euribor3m = 4.9, poutcome = c("nonexistent", "success"))
.p <- predict(.m, newdata = .h, type = "response")
.or <- exp(coef(.m)[["poutcomesuccess"]])
.low <- predict(.m, newdata = transform(.h, euribor3m = 0.7), type = "response")
.ev0 <- .p[1] * 50 - 5
.ok_p <- exists("p") && is.numeric(p) && length(p) == 2 && max(abs(p - .p)) < 1e-9
check_that(.ok_p && exists("odds_ratio") && abs(odds_ratio - .or) < 1e-6 && exists("change_pp") && abs(change_pp - 100 * (.p[2] - .p[1])) < 1e-6 &&
           exists("ev_call") && max(abs(ev_call - (.p * 50 - 5))) < 1e-9,
  sprintf(paste0("Memo: 'She has a %.1f%% chance of saying yes, about %d in 100 clients like her. A call is worth %.1f%% x $50 - $5 = %s$%.2f, so on its own it does not pay. ",
                 "Had our last campaign with her succeeded, her odds would be %.2f times as high (exactly exp(b) = %.2f), lifting her chance to %.1f%%, +%.1f percentage points, and the call would be worth +$%.2f.' ",
                 "The odds ratio is the same for every client; the percentage points are not. With Euribor at 0.7%% she would start at %.1f%%, and the same past success would add %.1f points instead of %.1f."),
          100 * .p[1], round(100 * .p[1]), 100 * .p[1], if (.ev0 < 0) "-" else "+", abs(.ev0), .or, .or, 100 * .p[2], 100 * (.p[2] - .p[1]), .p[2] * 50 - 5,
          100 * .low[1], 100 * (.low[2] - .low[1]), 100 * (.p[2] - .p[1])),
  if (!.ok_p) "p should hold two probabilities between 0 and 1: predict() needs type = \"response\"." else
  "Check the odds (p / (1 - p)), the change in percentage points (100 * (p[2] - p[1])) and the expected value (p * 50 - 5).")
