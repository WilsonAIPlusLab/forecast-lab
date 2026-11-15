#| **Load two years of daily bike rentals** (Capital Bikeshare, Washington, D.C.). Fit on January 2011 to August 2012; September to December 2012 is held back for the forecast test. `temp10 = 10 × temp` makes one unit about 4 to 5 °C.
import statsmodels.api as sm               # model families (Poisson, ...)
import statsmodels.formula.api as smf      # R-style formulas
bikes = pd.read_csv("data/bike_day.csv", parse_dates=["dteday"])   # one row per day, cnt = total rentals
# turn numeric codes into labelled categories; the first category listed is the baseline
bikes["weather"] = pd.Categorical(bikes["weathersit"].map({1: "clear", 2: "mist", 3: "rain/snow"}), ["clear", "mist", "rain/snow"])
bikes["season"] = pd.Categorical(bikes["season"].map({1: "winter", 2: "spring", 3: "summer", 4: "fall"}), ["winter", "spring", "summer", "fall"])
bikes["temp10"] = 10 * bikes["temp"]       # one unit = about 4 to 5 °C
train = bikes[bikes["dteday"] <= "2012-08-31"]   # fit on Jan 2011 - Aug 2012 only

#| **Mean versus variance.** A Poisson count has variance equal to its mean; daily rentals do not come close.
print({"mean": train["cnt"].mean(), "variance": train["cnt"].var(), "ratio": train["cnt"].var() / train["cnt"].mean()})   # Poisson expects ratio = 1

#| **Poisson regression** with a log link: `sm.families.Poisson()`. The coefficients match R's `glm(family = poisson)`.
# the model formula; I(temp10**2) adds a squared temperature term
f = "cnt ~ yr + season + holiday + workingday + weather + temp10 + I(temp10**2) + hum + windspeed"
pois = smf.glm(f, train, family=sm.families.Poisson()).fit()   # Poisson regression (log link)
print(pois.params.round(4))                # coefficients on the log scale

#| **Incidence-rate ratios:** exponentiate. 2012 runs about 56% above 2011; rain or snow about halves rentals.
irr = np.exp(pois.params)                  # IRR = exp(coef): 1.56 means 56% more rentals
print(irr.round(3))
# the yes/no and category effects to chart (statsmodels names categories like "season[T.spring]")
keep = ["yr", "season[T.spring]", "season[T.summer]", "season[T.fall]", "holiday", "workingday", "weather[T.mist]", "weather[T.rain/snow]"]
viz_bars(irr[keep].round(2), title="Rain or snow halves expected rentals; 2012 runs 56% above 2011",
         xlab="Incidence-rate ratio (1 = no effect)")

#| **Overdispersion check:** Pearson chi-square divided by residual degrees of freedom. About 100 instead of 1.
dispersion = pois.pearson_chi2 / pois.df_resid   # about 1 if Poisson fits
print(dispersion)

#| **Quasi-Poisson:** `scale="X2"` rescales the standard errors by the square root of the dispersion, as R's `quasipoisson` does.
qp = smf.glm(f, train, family=sm.families.Poisson()).fit(scale="X2")   # same fit, standard errors scaled up
# standard errors side by side for three coefficients (.loc picks rows by name)
print(pd.DataFrame({"poisson_se": pois.bse, "quasi_se": qp.bse}).loc[["yr", "weather[T.rain/snow]", "temp10"]].round(4))

#| **Negative binomial** by maximum likelihood. statsmodels reports `alpha` = 1/θ; we convert to R's θ. The log-likelihood based AIC matches R's `glm.nb`.
nb = smf.negativebinomial(f, train).fit(disp=0, maxiter=200)   # negative binomial regression, same formula
theta = 1 / nb.params["alpha"]             # convert alpha to R's theta
print({"theta": theta, "AIC_poisson": pois.aic, "AIC_negbin": nb.aic})   # lower AIC = better fit
# IRRs from both models for three coefficients: nearly the same (drop alpha, which is not a coefficient)
print(pd.DataFrame({"poisson": np.exp(pois.params), "negbin": np.exp(nb.params.drop("alpha"))}).loc[["yr", "workingday", "weather[T.rain/snow]"]].round(3))

#| **Where Poisson fits: small counts.** 4 a.m. on working days: the dispersion is about 1.7, nowhere near the 100 of the daily model.
hourly = pd.read_csv("data/bike_hour.csv")   # one row per hour
early = hourly[(hourly["hr"] == 4) & (hourly["workingday"] == 1)]   # 4 a.m. on working days only
pois4 = smf.glm("cnt ~ yr", early, family=sm.families.Poisson()).fit()
print({"mean": early["cnt"].mean(), "dispersion": pois4.pearson_chi2 / pois4.df_resid})

#| **Exposure.** Count the hours recorded per day in the hourly file. On October 29, 2012 only one hour was recorded (the system shut down for Hurricane Sandy). With varying exposure, add `offset=np.log(exposure)` to `smf.glm` so the model predicts a rate.
hours = hourly.groupby("dteday").size()    # number of hourly rows (hours recorded) per date
print(hours[hours < 20])                   # days with fewer than 20 hours of data
