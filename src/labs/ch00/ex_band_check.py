# Hidden check for ex_band: recompute the December numbers and compare.
_k = int(np.where(mean.index.month == 12)[0][0])
_ok = False
try:
    _ok = abs(float(point_bn) - mean.iloc[_k] / 1000) < 1e-6 and abs(float(high80_bn) - ci80.iloc[_k, 1] / 1000) < 1e-6
except Exception:
    pass
check_that(_ok,
    f"A manager-ready sentence: \"We expect December retail sales of about ${mean.iloc[_k] / 1000:,.0f} billion. "
    f"Anything from ${ci80.iloc[_k, 0] / 1000:,.0f} to ${ci80.iloc[_k, 1] / 1000:,.0f} billion would not surprise us; outside that range would be a 1-in-5 surprise.\" "
    f"The band is about ${(ci80.iloc[_k, 1] - ci80.iloc[_k, 0]) / 1000:,.0f} billion wide: that range, not the point, is the honest message.",
    "Two blanks. The data are in $ millions, so divide by 1000 to get $ billions. The band table has two columns: 0 is the lower bound, 1 is the upper bound.")
