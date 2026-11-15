check_that(exists("fc_h") && inherits(fc_h, "forecast") && length(fc_h$mean) == 18 && abs(fc_h$x[1] - fred("HOUSTNSA", start = 2010)[1]) < 1e-8,
  "Housing starts peak every spring and dip every winter, and the model has learned that rhythm. Yet the band keeps widening month after month. Why does uncertainty grow even when the seasonal pattern is so regular?",
  "Two blanks: the series ID must be the text \"HOUSTNSA\" (with quotes), and the horizon is the number 18.")
