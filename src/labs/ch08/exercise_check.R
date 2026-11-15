.r <- d$rec; .n <- length(.r)
.tw <- sapply(1:.n, function(i) if (i + 12 > .n) NA else max(.r[(i + 1):(i + 12)]))
.fw <- glm(.tw ~ d$spread, family = binomial)
.a <- local({ p <- fitted(.fw); y <- .fw$y; r <- rank(p); n1 <- sum(y == 1); n0 <- sum(y == 0); (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0) })
.fa <- glm(rec_ahead ~ spread, data = d, family = binomial)
.aa <- local({ p <- fitted(.fa); y <- .fa$y; r <- rank(p); n1 <- sum(y == 1); n0 <- sum(y == 0); (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0) })
check_that(exists("auc_w") && identical(as.numeric(d$rec_within), as.numeric(.tw)) && abs(auc_w - .a) < 1e-6,
  sprintf("AUC = %.3f for 'any recession in the next 12 months', against %.3f for 'recession in month t + 12'. The wider window sounds more natural, but it scores worse: it counts the months just before and during a recession as positives, and by then the Fed is usually cutting rates and the curve has steepened again. The spread's signal arrives about a year early, so a target pinned 12 months ahead matches it better. Choosing the target is a modeling decision, not a formality.", .a, .aa),
  "Check the two blanks. The window runs from i + 1 to i + 12, so the first blank is 12. A 0/1 target in glm() needs family = binomial.")
