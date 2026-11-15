_truth = fit.params["mr"] * (5 - now.mr)
check_that("gap" in globals() and abs(float(gap) - _truth) < 1e-6,
    f"Right: about {_truth:.2f} million more cars a year. That is exactly the mortgage-rate slope ({fit.params['mr']:.3f}) times the change in the rate (5 − {now.mr:.2f} = {5 - now.mr:.2f} points). In a linear model a scenario gap is always slope × change. But each 95% interval runs about 2.5 million either side of its forecast, so the gap is smaller than the uncertainty around either forecast. And rates rarely fall 2.3 points while unemployment stays put, so ask whether your scenario is internally consistent.",
    "Check both blanks: the low-rate scenario needs mr = 5, and the second get_prediction() call should use the low_rate data frame. The gap is low-rate minus today.")
