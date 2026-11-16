# Hidden check for ex_coverage: recomputes the audit and compares.
_in = (actual >= lo) & (actual <= hi)
_ok = "inside" in dir() and "coverage" in dir() and "below" in dir() and len(inside) == 24 and bool(np.all(np.asarray(inside) == _in)) and \
    abs(coverage - 100 * _in.mean()) < 1e-9 and below == np.sum(actual < lo)
_k = int(_in.sum())
check_that(_ok,
    f"{_k} of 24 months inside: {100 * _in.mean():.1f}% coverage against a promise of 80%. Misses: {np.sum(actual > hi)} above, {np.sum(actual < lo)} below. "
    f"Is that good? Even an honest 80% band lands between 16 and 22 hits in 24 months about 9 times in 10, so {_k} is "
    f"{'well within the normal range' if 16 <= _k <= 22 else 'outside the normal range'}. Now look at the sides: an honest band misses about equally often above and below. "
    "More misses on one side would mean the forecast itself is biased. Try start='2015-01-01': the band now remembers the 2020 swings and covers all 24 months, which sounds great but means it is too wide.",
    "Check the blanks. A hit needs actual >= lo AND actual <= hi. Coverage is 100 * np.mean(inside). For misses below the band, count the months where actual < lo.")
