# Hidden check for ex_memory: recompute the three numbers and compare.
.f <- ets(train); .a <- .f$par[["alpha"]]; .b <- .f$states[nrow(.f$states), "b"]
check_that(exists("alpha") && exists("half_life") && exists("slope") && isTRUE(abs(alpha - .a) < 1e-8) &&
             isTRUE(abs(half_life - log(0.5) / log(1 - .a)) < 1e-6) && isTRUE(abs(slope - .b) < 1e-6),
  sprintf("Your note to the manager: alpha = %.2f, so the newest month alone carries about %d%% of the level's weight and its half-life is about %.1f month; the level's information is on average only %.1f months old. Underlying online sales were growing by about $%d million a month in August 2025 (about $%.1f billion a year, before seasonal swings). A short memory suits a series that keeps shifting, but it also means one odd month moves the forecast a lot.",
          .a, round(100 * .a), log(0.5) / log(1 - .a), 1 / .a, round(.b), 12 * .b / 1000),
  "Check the blanks: the parameter is named \"alpha\" (in quotes); the half-life formula uses the alpha you just stored; and the slope column of fit$states is \"b\".")
