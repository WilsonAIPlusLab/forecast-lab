#| **Set up the forecast test.** Fit on January 2011 to August 2012; forecast each day of September to December 2012 (122 days). The model gets each test day's actual weather, as if the weather forecast were perfect.
import statsmodels.api as sm
import statsmodels.formula.api as smf
from scipy import stats
bikes = pd.read_csv("data/bike_day.csv", parse_dates=["dteday"])
bikes["weather"] = pd.Categorical(bikes["weathersit"].map({1: "clear", 2: "mist", 3: "rain/snow"}), ["clear", "mist", "rain/snow"])
bikes["season"] = pd.Categorical(bikes["season"].map({1: "winter", 2: "spring", 3: "summer", 4: "fall"}), ["winter", "spring", "summer", "fall"])
bikes["temp10"] = 10 * bikes["temp"]
train, test = bikes[bikes["dteday"] <= "2012-08-31"], bikes[bikes["dteday"] > "2012-08-31"]
f = "cnt ~ yr + season + holiday + workingday + weather + temp10 + I(temp10**2) + hum + windspeed"
pois = smf.glm(f, train, family=sm.families.Poisson()).fit()
nb = smf.negativebinomial(f, train).fit(disp=0, maxiter=200)
theta = 1 / nb.params["alpha"]

#| **Point forecasts and a naive benchmark** (tomorrow = today).
mu_p = pois.predict(test).to_numpy()
mu_n = nb.predict(test).to_numpy()
y = test["cnt"].to_numpy()
naive = bikes["cnt"].shift(1)[test.index].to_numpy()
print({"MAE_poisson": np.mean(np.abs(y - mu_p)), "MAE_negbin": np.mean(np.abs(y - mu_n)), "MAE_naive": np.mean(np.abs(y - naive))})

#| **Intervals from the count distributions.** scipy's negative binomial uses `n = θ` and `p = θ / (θ + μ)`, which is R's `size` and `mu` parametrization in disguise. `ppf` is the quantile function.
def interval(level):
    a = (1 - level) / 2
    nbd = stats.nbinom(theta, theta / (theta + mu_n))
    return dict(pois_lo=stats.poisson.ppf(a, mu_p), pois_hi=stats.poisson.ppf(1 - a, mu_p),
                nb_lo=nbd.ppf(a), nb_hi=nbd.ppf(1 - a))
i80, i95 = interval(0.80), interval(0.95)

#| **Coverage audit:** the share of days whose actual count fell inside each interval.
cov = lambda lo, hi: np.mean((y >= lo) & (y <= hi))
print(pd.DataFrame({"cover_80": [cov(i80["pois_lo"], i80["pois_hi"]), cov(i80["nb_lo"], i80["nb_hi"])],
                    "cover_95": [cov(i95["pois_lo"], i95["pois_hi"]), cov(i95["nb_lo"], i95["nb_hi"])],
                    "median_width_95": [np.median(i95["pois_hi"] - i95["pois_lo"]), np.median(i95["nb_hi"] - i95["nb_lo"])]},
                   index=["Poisson", "Negative binomial"]))

#| **Both fans.** Gold dots are what happened. The October 29 dip is Hurricane Sandy, when the system shut down.
for name, mu, k in [("Poisson", mu_p, "pois"), ("Negative binomial", mu_n, "nb")]:
    viz_custom("nl-fan", date=test["dteday"].dt.strftime("%Y-%m-%d").tolist(), actual=y.tolist(),
               hist_date=train["dteday"].tail(61).dt.strftime("%Y-%m-%d").tolist(), hist=train["cnt"].tail(61).tolist(),
               mean=np.round(mu).tolist(), lo80=i80[k + "_lo"].tolist(), hi80=i80[k + "_hi"].tolist(),
               lo95=i95[k + "_lo"].tolist(), hi95=i95[k + "_hi"].tolist(),
               title=f"{name}: the 95% interval caught {100 * cov(i95[k + '_lo'], i95[k + '_hi']):.0f}% of days",
               subtitle="Daily rentals, Sep–Dec 2012; bands = 80% and 95% prediction intervals",
               source="UCI Bike Sharing (Fanaee-T & Gama 2013), CC BY 4.0")
