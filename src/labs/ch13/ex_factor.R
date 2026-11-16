#| **You are the analyst.** Your manager wants one "consumer activity" number built from five spending series: consumer spending, retail sales excluding autos, auto dealers, vehicle unit sales and restaurants. Prepare the panel the right way, then run PCA. Fill the two blanks: turn each level into a **monthly growth rate**, then **standardize** every column before `prcomp()`.
ids <- c("PCE", "RSFSXMV", "RSMVPD", "TOTALSA", "RSFSDP")   # five monthly, seasonally adjusted series
# 1. Growth rate in % = 100 x change in log. Blank: the function that takes month-to-month changes
growth <- lapply(ids, function(id) 100 * ______(log(fred(id, start = 2009))))
panel <- window(do.call(cbind, growth), start = c(2010, 1), end = c(2019, 12))   # 2010-2019: no COVID
colnames(panel) <- ids                                  # name each column after its FRED ID

# 2. Standardize: each column gets mean 0 and sd 1. Blank: the base-R function that does this
Z <- ______(panel)
pc <- prcomp(Z)                                         # principal components of the standardized panel
share <- pc$sdev^2 / sum(pc$sdev^2)                     # share of total variance per component
w <- pc$rotation[, 1]                                   # loadings (weights) of component 1
if (w["PCE"] < 0) w <- -w                               # sign is arbitrary: make spending load positively
round(share, 3)                                         # read the first number as "% of variance explained"
round(w, 2)                                             # every series should carry real weight
