.d  <- forecast::ndiffs(u)
.f  <- forecast::auto.arima(u, d = .d, seasonal = FALSE)
.lb <- Box.test(residuals(.f), lag = 24, type = "Ljung-Box", fitdf = length(coef(.f)))
.fc <- forecast::forecast(.f, h = 4)$mean[4]
.verdict <- if (.lb$p.value < 0.05) "just under 0.05: a little autocorrelation is left. With 360 months the test can flag very small correlations, so look at the residual ACF before you add more terms" else "above 0.05, so the residuals look like white noise"
check_that(exists("d") && identical(as.numeric(d), as.numeric(.d)) && exists("lb") && inherits(lb, "htest") &&
             lb$parameter == 24 - length(coef(.f)) && abs(lb$p.value - .lb$p.value) < 1e-8,
  sprintf("Right: d = %d, auto.arima() picks %s, and the Ljung-Box p-value is %.3f, %s. Now the humbling part: this model's forecast for April 2020, made at the end of 2019, is %.1f%%. The actual rate was 14.8%%. A univariate model can only extrapolate the past; it cannot see a pandemic coming.",
          .d, forecast:::arima.string(.f, padding = FALSE), .lb$p.value, .verdict, .fc),
  "Two things to check. The helper that counts differences is ndiffs(). And fitdf is the number of estimated ARMA coefficients, length(coef(fit)), so the test has 24 minus that many degrees of freedom.")
