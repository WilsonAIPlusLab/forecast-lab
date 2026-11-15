.fit <- ets(train)
.fc  <- forecast(.fit, h = length(test))
.truth <- accuracy(.fc, test)["Test set", "MASE"]
.sn <- accuracy(snaive(train, h = length(test)), test)["Test set", "MASE"]
check_that(exists("mase") && is.numeric(mase) && length(mase) == 1 && abs(mase - .truth) < 1e-6,
  sprintf("MASE = %.2f with %s. Seasonal naive scores %.2f on the same months, so ETS cuts the error by about %d%%. Notice the N: no trend term. Annual clothing sales grew only about 1.8%% a year from 2015 to 2025 (about $250 billion to $300 billion), with the 2020 collapse in between. AICc judged a slope not worth its extra parameter; the level update (alpha) absorbs the slow growth.",
          .truth, .fit$method, .sn, round(100 * (1 - .truth / .sn))),
  "Check the three blanks: the function is ets(); the horizon should cover the whole test set, length(test) (or 12); and the column name in accuracy() is \"MASE\" in capitals.")
