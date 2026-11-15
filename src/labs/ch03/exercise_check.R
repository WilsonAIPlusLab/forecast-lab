.truth <- mean(abs(test - snaive(train, h = length(test))$mean))
check_that(exists("mae") && is.numeric(mae) && abs(mae - .truth) < 1e-6,
  sprintf("MAE = %s. Every error is positive: this series is seasonally adjusted and growing fast, so 'same month last year' is always too low. Now try drift, rwf(train, h = length(test), drift = TRUE): its MAE is roughly 2,000.", format(round(.truth), big.mark = ",")),
  "Check two things: the function for seasonal naive is snaive(), and the error is actual minus forecast, so the first blank is the test set.")
