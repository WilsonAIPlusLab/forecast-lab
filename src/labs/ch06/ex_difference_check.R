# Hidden check for ex_difference: compares with the tests run here.
.y <- fred("GS10", start = 1990, quiet = TRUE)
.pk <- suppressWarnings(tseries::kpss.test(.y)$p.value)
.pa <- suppressWarnings(tseries::adf.test(.y)$p.value)
.pad <- suppressWarnings(tseries::adf.test(diff(.y))$p.value)
.pkd <- suppressWarnings(tseries::kpss.test(diff(.y))$p.value)
.r1 <- acf(diff(.y), lag.max = 1, plot = FALSE)$acf[2]
check_that(exists("p_kpss") && abs(p_kpss - .pk) < 1e-8 && exists("dy") && length(dy) == length(.y) - 1 &&
             isTRUE(all.equal(as.numeric(dy), as.numeric(diff(.y)))) && exists("d") && identical(as.numeric(d), 1),
  sprintf("Right: d = 1. Here is the defense you would write: \"In levels, ADF cannot reject a unit root (p = %.2f) and KPSS rejects stationarity (p = %.2f), so both tests say the yield wanders. Its monthly change passes both tests (ADF p = %.2f, KPSS p = %.2f), so one difference is enough.\" One more check: the change has a lag-1 autocorrelation of %.2f, far from the -0.5 that would warn of over-differencing. Interest rates cannot trend forever, but since 1990 the 10-year yield fell from about 8%% to under 1%% and climbed back above 5%%, which behaves like a unit root over any forecasting horizon.",
          .pa, .pk, .pad, .pkd, .r1),
  "Check three things. The test with the null 'stationary' is kpss.test(). The first difference is diff(y). And d: in levels both tests point to a unit root, while the change looks stationary, so how many differences do you need?")
