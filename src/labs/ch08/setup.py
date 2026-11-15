# Hidden setup shared by the Chapter 8 labs: rebuilds the DataFrame `d` from the first lab.
rec = fred("USREC", start=1959)
spread = fred("GS10", start=1959) - fred("TB3MS", start=1959)
d = pd.DataFrame({"spread": spread, "rec": rec}).dropna()
d["rec_ahead"] = d["rec"].shift(-12)
known = d.dropna(subset=["rec_ahead"]).copy()
