#| **Pre-COVID retail sales, in logs.**
retail = fred("RSXFSN", start=2010, end="2019-12-01")   # monthly retail sales, $ millions, NSA, 2010-2019
y = np.log(retail)                            # natural log of sales

#| **Detrend by regression**: a time counter plus 11 month dummies (January is the baseline), the same model as R's `tslm(y ~ trend + season)`.
import statsmodels.api as sm                  # statistical models, including OLS regression
# one 0/1 column per month; drop_first=True drops January so it becomes the baseline
X = pd.get_dummies(y.index.month, prefix="season", drop_first=True, dtype=float)
X.insert(0, "trend", np.arange(1, len(y) + 1))   # add the time counter 1, 2, 3, ... as the first column
X = sm.add_constant(X.set_index(y.index))     # use the dates as row labels and add an intercept column
fit = sm.OLS(y, X).fit()                      # ordinary least squares: log sales on trend + month dummies
print((100 * fit.params[["trend", "season_2", "season_11", "season_12"]]).round(2))   # four coefficients, x 100

#| **Annualized trend growth**, in percent.
print(round(100 * (np.exp(12 * fit.params["trend"]) - 1), 1))   # 12 months of log growth -> annual % growth

#| **Differencing**: subtract the value 12 months earlier to get year-over-year growth.
yoy = y.diff(12).dropna()                     # y now minus y a year ago; drop the first 12 empty months

#| **Compare the leftovers.**
viz_ts(**{"Residual from trend + season regression": 100 * fit.resid,   # what the regression could not explain
          "Year-over-year growth (12-month difference)": 100 * yoy},
       facet=True, ylab="% (log points)",     # facet = one panel per series
       title="Two ways to remove trend and seasonality leave different leftovers")
