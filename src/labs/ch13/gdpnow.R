#| **Two quarterly series.** `GDPNOW` holds the Atlanta Fed's *final* GDPNow nowcast for each quarter, the last one before BEA's advance estimate. `A191RL1Q225SBEA` is real GDP growth (% annualized, SA) **as it stands today, after all revisions**. That is not what GDPNow was trying to hit on release day. It aimed at the advance estimate, which is not bundled here. Keep that in mind for every number below.
now    <- fred("GDPNOW")                               # final GDPNow nowcast per quarter, % annualized
actual <- fred("A191RL1Q225SBEA")                      # real GDP growth, latest revised data, % annualized
# side by side; stats::lag(actual, -1) shifts it one quarter later = last quarter's growth; drop gaps
x <- na.omit(cbind(nowcast = now, actual = actual, last_q = stats::lag(actual, -1)))
d <- data.frame(quarter = ts_dates(x), as.data.frame(x))   # data frame with a date column
d$error <- d$actual - d$nowcast                        # error = actual minus nowcast (positive = nowcast too low)
c(first = d$quarter[1], last = tail(d$quarter, 1), n = nrow(d))   # sample span and number of quarters

#| **Nowcast vs outcome.** Points on the diagonal would be perfect nowcasts. The two COVID quarters (2020 Q2 at about −28%, Q3 at about +35%) stretch the axes. GDPNow called their direction and rough size correctly. Everything else sits in a tight cloud near the middle.
viz_custom("ch13-scatter45", x = d$nowcast, y = d$actual, labels = d$quarter,   # scatter with a 45-degree line
           xlab = "GDPNow final nowcast (% annualized)", ylab = "Real GDP growth, latest vintage (%)",
           title = "GDPNow tracks the big swings; the everyday misses are a point or two",
           source = "FRED, Federal Reserve Bank of St. Louis (GDPNOW, A191RL1Q225SBEA)")

#| **Score it**, with and without the two COVID quarters, against a naive benchmark ("growth will equal last quarter's"). One caveat: the naive forecast here also uses today's revised data for last quarter, which nobody had at the time. GDPNow beats naive by a wide margin either way. Notice the positive mean error: on average, growth (as revised) came in a bit *above* the final nowcast.
# helper: accuracy summary for a set of quarters; Naive MAE uses last quarter's growth as the forecast
score <- function(z) c(n = nrow(z), MAE = mean(abs(z$error)), RMSE = sqrt(mean(z$error^2)),
                       `Mean error` = mean(z$error), `Naive MAE` = mean(abs(z$actual - z$last_q)))
covid <- d$quarter %in% c("2020-04-01", "2020-07-01")  # TRUE for 2020 Q2 and Q3
tab <- rbind(`All quarters` = score(d), `Excluding 2020 Q2-Q3` = score(d[!covid, ]))   # ! = "not"
round(tab, 2)                                          # percentage points
viz_table(tab, digits = 2, title = "GDPNow vs revised GDP: typical miss about 1.3 points")

#| **The biggest misses.** Read them as stories, not just numbers.
#| - **2020 Q1 and Q2**: the pandemic changed the economy faster than any model's inputs.
#| - **2025 Q4**: this quarter spanned the 43-day federal shutdown, when many source data were delayed or never collected.
#| - **2015 Q1**: GDPNow said 0.1%, and BEA's advance estimate said 0.2%, a near-perfect nowcast. It shows up as a 3.5-point "miss" only because later revisions raised that quarter to 3.6%.
d[order(-abs(d$error))[1:5], c("quarter", "nowcast", "actual", "error")]   # sort by largest absolute error, top 5

#| **Why "1.3 points" is not GDPNow's official track record.** The Atlanta Fed scores its final nowcasts against BEA's *advance* estimate and reports an average absolute error of 0.76 points for 2011 Q3 to 2026 Q3. Ours is larger because today's numbers include years of revisions. BEA itself reports that real GDP growth moves by 1.21 points on average from the advance estimate to the latest one (1999–2022). Part of every "nowcast error" is really a data revision.
# three headline numbers: our MAE (excluding COVID), and two published figures typed in by hand
viz_kpi(`Our MAE vs latest vintage` = round(tab[2, "MAE"], 2), `Atlanta Fed MAE vs advance` = 0.76,
        `BEA: avg revision, advance to latest` = 1.21, title = "Which truth are you scoring against?")
