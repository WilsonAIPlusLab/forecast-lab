library(vars)                                 # VAR estimation and impulse responses
q <- function(id) fred(id, to = "quarter")    # helper: FRED series as quarterly averages
# inflation (annualized %), unemployment (%), funds rate (%); keep quarters where all three exist
y <- na.omit(ts.intersect(400 * diff(log(q("CPIAUCSL"))), q("UNRATE"), q("FEDFUNDS")))
y <- window(y, start = c(1960, 1), end = c(2000, 4))   # 1960Q1 to 2000Q4
colnames(y) <- c("infl", "unemp", "ffr")      # baseline ordering: the Fed moves last
m <- VAR(y, p = 4, type = "const")            # VAR(4) with a constant

# responses to a one-standard-deviation funds-rate shock; rows are h = 0, 1, ..., 20
r <- irf(m, impulse = "ffr", n.ahead = 20, ortho = TRUE, boot = FALSE)$irf$ffr
size <- r[1, "ffr"]                           # how big that shock is: the funds rate's own jump on impact (pp)

# 1. Rescale the unemployment response to a 1-percentage-point surprise hike
# blank: the number to divide by (how many pp the funds rate jumped on impact)
unemp_1pp <- r[, "unemp"] / ______

# 2. The response 8 quarters (two years) after the hike
# blank: the ROW that holds h = 8 (row 1 is h = 0, the shock quarter)
at8 <- unemp_1pp[______]

# 3. When does unemployment peak? which.max() gives a row number; turn it into quarters after the hike
# blank: how much to subtract so that row 1 becomes quarter 0
peak_q <- which.max(unemp_1pp) - ______
c(size = size, at8 = at8, peak_q = peak_q)    # the three numbers for your CFO
