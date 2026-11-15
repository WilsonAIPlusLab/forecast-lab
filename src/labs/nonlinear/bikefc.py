#| **Set up the forecast test.** Fit on January 2011 to August 2012; forecast each day of September to December 2012 (122 days). The model gets each test day's actual weather, as if the weather forecast were perfect.
import statsmodels.api as sm               # model families (Poisson, ...)
import statsmodels.formula.api as smf      # R-style formulas
from scipy import stats                    # probability distributions for the intervals
bikes = pd.read_csv("data/bike_day.csv", parse_dates=["dteday"])   # one row per day, cnt = total rentals
# turn numeric codes into labelled categories; the first category listed is the baseline
bikes["weather"] = pd.Categorical(bikes["weathersit"].map({1: "clear", 2: "mist", 3: "rain/snow"}), ["clear", "mist", "rain/snow"])
bikes["season"] = pd.Categorical(bikes["season"].map({1: "winter", 2: "spring", 3: "summer", 4: "fall"}), ["winter", "spring", "summer", "fall"])
bikes["temp10"] = 10 * bikes["temp"]       # one unit = about 4 to 5 °C
# fit on Jan 2011 - Aug 2012; forecast Sep - Dec 2012
train, test = bikes[bikes["dteday"] <= "2012-08-31"], bikes[bikes["dteday"] > "2012-08-31"]
# the model formula; I(temp10**2) adds a squared term so rentals can dip on the hottest days
f = "cnt ~ yr + season + holiday + workingday + weather + temp10 + I(temp10**2) + hum + windspeed"
pois = smf.glm(f, train, family=sm.families.Poisson()).fit()   # Poisson regression (log link)
nb = smf.negativebinomial(f, train).fit(disp=0, maxiter=200)   # negative binomial: same formula, extra variance
theta = 1 / nb.params["alpha"]             # statsmodels reports alpha = 1/theta; convert to R's theta

#| **Point forecasts and a naive benchmark** (tomorrow = today).
mu_p = pois.predict(test).to_numpy()       # expected count for each test day
mu_n = nb.predict(test).to_numpy()
y = test["cnt"].to_numpy()                 # actual counts
naive = bikes["cnt"].shift(1)[test.index].to_numpy()   # naive: .shift(1) = the day before's count
# mean absolute error of each method, in bikes per day
print({"MAE_poisson": np.mean(np.abs(y - mu_p)), "MAE_negbin": np.mean(np.abs(y - mu_n)), "MAE_naive": np.mean(np.abs(y - naive))})

#| **Intervals from the count distributions.** scipy's negative binomial uses `n = θ` and `p = θ / (θ + μ)`, which is R's `size` and `mu` parametrization in disguise. `ppf` is the quantile function.
def interval(level):                       # lower and upper bounds for a given interval level
    a = (1 - level) / 2                    # tail probability: 0.10 for an 80% interval
    nbd = stats.nbinom(theta, theta / (theta + mu_n))   # one negative binomial distribution per test day
    return dict(pois_lo=stats.poisson.ppf(a, mu_p), pois_hi=stats.poisson.ppf(1 - a, mu_p),   # Poisson percentiles
                nb_lo=nbd.ppf(a), nb_hi=nbd.ppf(1 - a))
i80, i95 = interval(0.80), interval(0.95)

#| **Coverage audit:** the share of days whose actual count fell inside each interval.
cov = lambda lo, hi: np.mean((y >= lo) & (y <= hi))   # share of days inside [lo, hi]
# 80% coverage should be near 0.80, 95% near 0.95; width in bikes
print(pd.DataFrame({"cover_80": [cov(i80["pois_lo"], i80["pois_hi"]), cov(i80["nb_lo"], i80["nb_hi"])],
                    "cover_95": [cov(i95["pois_lo"], i95["pois_hi"]), cov(i95["nb_lo"], i95["nb_hi"])],
                    "median_width_95": [np.median(i95["pois_hi"] - i95["pois_lo"]), np.median(i95["nb_hi"] - i95["nb_lo"])]},
                   index=["Poisson", "Negative binomial"]))

#| **Both fans.** Gold dots are what happened. The October 29 dip is Hurricane Sandy, when the system shut down.
for name, mu, k in [("Poisson", mu_p, "pois"), ("Negative binomial", mu_n, "nb")]:   # k picks the interval keys
    # dates as "YYYY-MM-DD" text; history = last 61 training days
    viz_custom("nl-fan", date=test["dteday"].dt.strftime("%Y-%m-%d").tolist(), actual=y.tolist(),
               hist_date=train["dteday"].tail(61).dt.strftime("%Y-%m-%d").tolist(), hist=train["cnt"].tail(61).tolist(),
               mean=np.round(mu).tolist(), lo80=i80[k + "_lo"].tolist(), hi80=i80[k + "_hi"].tolist(),
               lo95=i95[k + "_lo"].tolist(), hi95=i95[k + "_hi"].tolist(),
               title=f"{name}: the 95% interval caught {100 * cov(i95[k + '_lo'], i95[k + '_hi']):.0f}% of days",
               subtitle="Daily rentals, Sep–Dec 2012; bands = 80% and 95% prediction intervals",
               source="UCI Bike Sharing (Fanaee-T & Gama 2013), CC BY 4.0")
