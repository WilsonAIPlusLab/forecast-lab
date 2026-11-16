#| **Solution.** `np.log(x).diff()` turns each trending level into a stationary growth rate, and dividing by `.std()` puts every series in standard-deviation units. Now component 1 explains about 46.5% of the movement in five series, and all five load positively: it really is a common "spending" factor.
ids = ["PCE", "RSFSXMV", "RSMVPD", "TOTALSA", "RSFSDP"]  # five monthly, seasonally adjusted series
# 1. Growth rate in % = 100 x change in log (.diff() takes month-to-month changes); keep 2010-2019
panel = pd.DataFrame({i: 100 * np.log(fred(i, start=2009)).diff() for i in ids})["2010-01":"2019-12"]

# 2. Standardize: subtract each column's mean, divide by its standard deviation
Z = (panel - panel.mean()) / panel.std()
# PCA via the singular value decomposition (what R's prcomp does): rows of Vt are the loadings
_, sv, Vt = np.linalg.svd(Z.values, full_matrices=False)
share = sv**2 / np.sum(sv**2)                           # share of total variance per component
w = pd.Series(Vt[0], index=ids)                         # loadings (weights) of component 1
if w["PCE"] < 0: w = -w                                 # sign is arbitrary: make spending load positively
print(share.round(3))                                   # read the first number as "% of variance explained"
print(w.round(2))                                       # every series should carry real weight
