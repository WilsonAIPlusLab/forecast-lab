# Hidden check for ex_irf_units: recompute the answer and compare.
_oi = VAR(y).fit(4).irf(20).orth_irfs
_u = _oi[:, 1, 2] / _oi[0, 2, 2]
_ok_size = "unemp_1pp" in globals() and len(unemp_1pp) == 21 and np.allclose(np.asarray(unemp_1pp, dtype=float), _u)
check_that(_ok_size and "at8" in globals() and abs(float(at8) - _u[8]) < 1e-9 and "peak_q" in globals() and peak_q == int(np.argmax(_u)),
    f"Your sentence for the CFO: \"A 1-percentage-point surprise rise in the funds rate is followed by an unemployment rate about {_u[8]:.2f} points higher two years later "
    f"than it would otherwise have been, with the peak {int(np.argmax(_u))} quarters after the hike.\" The VAR's own shock was {_oi[0, 2, 2]:.2f} pp, so every number in the "
    f"chapter's charts is {_oi[0, 2, 2]:.2f} times the numbers here. Responses are linear: a 25-basis-point surprise would move unemployment by a quarter as much, about {_u[8] / 4:.3f} points.",
    "Step 1: divide the whole unemployment response by size, the funds rate's own jump on impact (about 0.76 pp). Then each number is \"per 1 pp of surprise\"."
    if not _ok_size else "Row labels are quarters after the shock (0 = the shock quarter), so h = 8 is .loc[8], and .idxmax() returns the quarter of the peak.")
