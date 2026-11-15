#| **Core PCE prices**, the Federal Reserve's preferred inflation gauge (index 2017 = 100, monthly, seasonally adjusted). We take logs, because then a difference is (almost exactly) a percentage change.
library(forecast)
pce <- fred("PCEPILFE", start = c(2000, 1))
lp  <- log(pce)

#| **The ACF of a trending level is a giveaway.** Every autocorrelation is close to 1 and they fade only very slowly. That slow, straight-line decay is the classic signature of a nonstationary series. Nothing about the dynamics can be read from it: the trend swamps everything.
viz_acf(lp, lag.max = 36, title = "Log price level: autocorrelations fade very slowly, a sign of a unit root")

#| **One difference turns prices into inflation.** `1200 * diff(lp)` is the monthly change in log prices, annualized to "percent per year" so it is comparable with the familiar 2% target.
infl <- 1200 * diff(lp)
viz_ts(infl, title = "Monthly core PCE inflation, annualized", ylab = "% per year (annualized m/m)")

#| **Now the ACF and PACF of inflation.** The ACF still decays *slowly*: about 0.4 at lag 1 and still above 0.2 a year later. The PACF has a few significant spikes at short lags and then dies out. Inflation is very persistent: maybe stationary, maybe not. Keep that in mind; it is the central judgment call of this chapter.
viz_acf(infl, lag.max = 36, title = "Inflation ACF: slow decay, so shocks to inflation linger")
viz_acf(infl, lag.max = 36, type = "pacf", title = "Inflation PACF: a few short-lag spikes, then noise")

#| **Difference once more** and the picture snaps into a textbook shape: one big *negative* spike at lag 1 in the ACF (about −0.45) and almost nothing after. A single ACF spike that then cuts off is the signature of an **MA(1)**. So changes in inflation look like MA(1), which means inflation itself looks like ARIMA(0,1,1).
dinfl <- diff(infl)
viz_acf(dinfl, lag.max = 36, title = "Change in inflation: one negative spike at lag 1, the MA(1) signature")
round(acf(dinfl, lag.max = 3, plot = FALSE)$acf[2:4], 3)

#| **Seasonal data need a seasonal difference.** Retail sales are *not* seasonally adjusted, so December towers over every other month. `nsdiffs()` asks how many lag-12 differences ($y_t - y_{t-12}$) are needed; `ndiffs()` then checks what is left.
retail <- log(fred("RSXFSN", start = 2010, end = c(2019, 12)))
c(seasonal = nsdiffs(retail), regular_after = ndiffs(diff(retail, lag = 12)))
