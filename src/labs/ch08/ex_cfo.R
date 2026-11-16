# Your CFO asks: "What does the yield curve say about a recession a year from now, in plain words?
# And how much would it change if the curve flattened by a quarter point?"
# The data frame d (date, spread, rec, rec_ahead) and known (rows with a known answer) are ready.
# blank: the glm() family for a 0/1 (yes/no) outcome
logit <- glm(rec_ahead ~ spread, data = known, family = ______)

latest <- tail(d, 1)                 # the latest month: spread known, outcome 12 months later not yet
latest$date                          # the month the spread was measured
latest$spread                        # the spread, in percentage points (10-year minus 3-month yield)

# 1. Probability that the month 12 months from now is a recession month
p_now <- predict(logit, newdata = latest, type = "response")

# 2. The same forecast if the spread were 25 basis points LOWER (a flatter curve)
# blank: 25 basis points, written in the spread's units (percentage points)
p_flat <- predict(logit, newdata = data.frame(spread = latest$spread - ______), type = "response")
change_pp <- 100 * (p_flat - p_now)  # change in percentage points of probability

# 3. Compare with the base rate: the share of all known months followed by a recession
# blank: the column that holds the 0/1 target
base <- mean(known$______)
ratio_to_base <- p_now / base        # above 1 = more risk than usual, below 1 = less
round(c(p_now = unname(p_now), p_flat = unname(p_flat), change_pp = unname(change_pp),
        base = base, ratio_to_base = unname(ratio_to_base)), 3)
