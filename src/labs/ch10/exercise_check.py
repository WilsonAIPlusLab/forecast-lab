_cr = cu / (cu + co)
_q = np.quantile(demand, _cr)
check_that("cr" in dir() and abs(cr - _cr) < 1e-9 and "stock" in dir() and abs(stock - _q) < 1e-6,
    f"Critical ratio = {_cr:.2f}, so stock {_q:,.0f} ($ millions), which is {np.median(demand) - _q:,.0f} below the median forecast. "
    f"When leftovers cost more than shortages, the best plan deliberately runs out in about {100 * (1 - _cr):.0f}% of scenarios. Safety stock can be negative.",
    "Check both blanks. The critical ratio is cu / (cu + co): the cost of running short divided by the total of both costs. Then pass that ratio (the variable cr) as the probability in np.quantile().")
