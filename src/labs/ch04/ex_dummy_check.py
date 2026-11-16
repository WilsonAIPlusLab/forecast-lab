# Hidden check: compares the student's two percent gaps with the truth.
_b = smf.ols("np.log(y) ~ trend + C(month) + covid", data=train).fit().params
_dj = 100 * (np.exp(_b["C(month)[T.12]"]) - 1); _dn = 100 * (np.exp(_b["C(month)[T.12]"] - _b["C(month)[T.11]"]) - 1)
_has = "dec_vs_jan" in globals() and "dec_vs_nov" in globals()
_ok = _has and abs(float(dec_vs_jan) - _dj) < 1e-6 and abs(float(dec_vs_nov) - _dn) < 1e-6
check_that(_ok,
    f"Right. December runs {_dj:.1f}% above January and {_dn:.1f}% above November, holding the trend fixed. Two lessons: (1) a dummy's coefficient is always a gap from the base month, so to compare two other months you subtract their coefficients first; (2) for big log coefficients the shortcut 100 × b misleads: December's b is {_b['C(month)[T.12]']:.3f}, which reads as {100 * _b['C(month)[T.12]']:.1f}% but is really {_dj:.1f}%.",
    "December vs January is right. For December vs November, subtract November's coefficient, b[\"C(month)[T.11]\"], inside np.exp()." if _has and abs(float(dec_vs_jan) - _dj) < 1e-6
    else "December's coefficient is named \"C(month)[T.12]\" (T.2 is February, so T.12 is December). Put the name in quotes inside b[ ].")
