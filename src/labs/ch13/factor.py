#| **Twenty indicators, one recipe.** Write one function and apply it over a list: levels become monthly growth rates (100 × change in log), rates and spreads become monthly changes, and weekly or daily series are averaged to months first.
from sklearn.decomposition import PCA
growth = ["PAYEMS", "IANA", "INDPRO", "HOUST", "PERMIT", "DSPIC96", "TOTALSA", "PCE", "RSFSXMV",
          "RSMVPD", "RSFHFS", "RSEAS", "RSDBS", "RSCCAS", "RSFSDP", "ICSA", "CCSA"]
changes = ["AWHMAN", "BAA10Y", "NFCI"]
weekly_or_daily = ["ICSA", "CCSA", "BAA10Y", "NFCI"]
def transform1(id):
    x = fred(id, to="month" if id in weekly_or_daily else None)
    return 100 * np.log(x).diff() if id in growth else x.diff()

#| **Stack into a panel**: rows are months, columns are series. Keep the months where all 20 exist.
panel = pd.concat({id: transform1(id) for id in growth + changes}, axis=1, sort=True)
panel = panel.loc["1993-01":"2026-09"].dropna()
print(panel.shape)

#| **Standardize (same n − 1 formula as R's `scale`), then clip at ±4 standard deviations** so April 2020 can't hijack the factor.
Z = (panel - panel.mean()) / panel.std()
print("clipped cells:", int((Z.abs() > 4).sum().sum()))
Z = Z.clip(-4, 4)

#| **PCA with scikit-learn.** `explained_variance_ratio_` is the scree plot. It should match R's `prcomp` exactly.
pca = PCA().fit(Z)
share = pca.explained_variance_ratio_
print(share[:5].round(3))
viz_bars(100 * share[:8].round(3), labels=[f"PC {i}" for i in range(1, 9)], sort=False,
         title="One factor stands out: share of variance explained (%)", xlab="% of total variance")

#| **Loadings**, with the sign flipped so payrolls load positively (the sign of a component is arbitrary).
w = pd.Series(pca.components_[0], index=Z.columns)
if w["PAYEMS"] < 0:
    w = -w
viz_bars(w.round(2), title="Almost every indicator loads on the factor, with the expected sign",
         xlab="loading on component 1")

#| **The factor through time** (3-month average), with recessions shaded.
factor = Z @ w
ma3 = factor.rolling(3).mean()
viz_ts(**{"Activity factor (3-mo avg)": ma3}, recessions=True, ylab="standard units",
       title="One line summarizes 20 indicators, and it falls in every recession")
print(ma3.tail(3).round(2))
