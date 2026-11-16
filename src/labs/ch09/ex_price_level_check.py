# Hidden check for ex_price_level: recompute the answer and compare.
_oi = VAR(y).fit(4).irf(20).orth_irfs
_pl = np.cumsum(_oi[:, 0, 2] / _oi[0, 2, 2]) / 4
_ok_cum = "cum_infl" in globals() and len(cum_infl) == 21 and np.allclose(np.asarray(cum_infl, dtype=float), 4 * _pl)
_ok_pl = "price_1pp" in globals() and len(price_1pp) == 21 and np.allclose(np.asarray(price_1pp, dtype=float), _pl)
check_that(_ok_pl and "price12" in globals() and abs(float(price12) - _pl[12]) < 1e-9,
    f"Two quarters after a 1-pp surprise hike the CPI is about {_pl[2]:+.2f}% versus no hike (the price puzzle, now in the price level); three years after, it is about {_pl[12]:+.2f}%. "
    "Notice how small both numbers are: the inflation response looked like a quarter-point swing, but in the level it is about a tenth of a percent, and the chapter's 90% band "
    "for this path includes zero from the third quarter on. A growth-rate response and a level response answer different questions, so say which one you report.",
    "Step 1 needs running totals of infl_1pp: the pandas .cumsum() method." if not _ok_cum else
    "Step 2: the inflation series is 400 x the quarterly log change, so a summed annualized rate must be divided by 4 to become a % change in the price level." if not _ok_pl else
    "Row labels are quarters after the hike, so h = 12 is .loc[12].")
