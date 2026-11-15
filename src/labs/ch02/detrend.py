#| **Pre-COVID retail sales, in logs.**
retail = fred("RSXFSN", start=2010, end="2019-12-01")
y = np.log(retail)

#| **Detrend by regression**: a time counter plus 11 month dummies (January is the baseline), the same model as R's `tslm(y ~ trend + season)`.
import statsmodels.api as sm
X = pd.get_dummies(y.index.month, prefix="season", drop_first=True, dtype=float)
X.insert(0, "trend", np.arange(1, len(y) + 1))
X = sm.add_constant(X.set_index(y.index))
fit = sm.OLS(y, X).fit()
print((100 * fit.params[["trend", "season_2", "season_11", "season_12"]]).round(2))

#| **Annualized trend growth**, in percent.
print(round(100 * (np.exp(12 * fit.params["trend"]) - 1), 1))

#| **Differencing**: subtract the value 12 months earlier to get year-over-year growth.
yoy = y.diff(12).dropna()

#| **Compare the leftovers.**
viz_ts(**{"Residual from trend + season regression": 100 * fit.resid,
          "Year-over-year growth (12-month difference)": 100 * yoy},
       facet=True, ylab="% (log points)",
       title="Two ways to remove trend and seasonality leave different leftovers")
