#| **Load two years of daily bike rentals** from Capital Bikeshare in Washington, D.C. `cnt` counts every rental that day. We keep January 2011 to August 2012 for fitting and hide September to December 2012 for the forecast test in the next lab. `temp` is a normalized temperature (0 to 1); `temp10 = 10 × temp` makes one unit about 4 to 5 °C.
bikes <- read.csv("data/bike_day.csv")     # one row per day, cnt = total rentals
bikes$date <- as.Date(bikes$dteday)        # text -> Date so we can compare dates
# turn numeric codes into labelled categories (factors); the first level is the baseline
bikes$weather <- factor(bikes$weathersit, levels = 1:3, labels = c("clear", "mist", "rain/snow"))
bikes$season <- factor(bikes$season, levels = 1:4, labels = c("winter", "spring", "summer", "fall"))
bikes$temp10 <- 10 * bikes$temp            # one unit = about 4 to 5 °C
train <- subset(bikes, date <= as.Date("2012-08-31"))   # fit on Jan 2011 - Aug 2012 only
src <- "UCI Bike Sharing (Fanaee-T & Gama 2013), CC BY 4.0"   # data credit for the charts

#| **First check: mean versus variance.** A Poisson count has variance equal to its mean. Daily rentals have a variance hundreds of times larger than the mean. Some of that is explained by weather and season, which the model will absorb; we will see how much is left.
c(mean = mean(train$cnt), variance = var(train$cnt), ratio = var(train$cnt) / mean(train$cnt))   # Poisson expects ratio = 1

#| **Poisson regression.** `family = poisson` uses a **log link**: the model predicts $\log(\text{expected rentals})$ as a straight line in the predictors, so the expected count itself is always positive. The temperature enters with a square term because rentals fall again on the hottest days.
# the model formula; I(temp10^2) adds a squared temperature term
f <- cnt ~ yr + season + holiday + workingday + weather + temp10 + I(temp10^2) + hum + windspeed
pois <- glm(f, family = poisson, data = train)   # Poisson regression (log link)
round(coef(pois), 4)                       # coefficients on the log scale

#| **Read the coefficients as incidence-rate ratios (IRR).** Because of the log link, $e^b$ *multiplies* expected rentals. 2012 runs about 56% above 2011 (the system was growing); a rain-or-snow day has about half the rentals of a clear day, other things equal.
irr <- exp(coef(pois))                     # IRR = exp(coef): 1.56 means 56% more rentals
round(irr, 3)
# chart only the yes/no and category effects (names come from the coefficient table)
viz_bars(round(irr[c("yr", "seasonspring", "seasonsummer", "seasonfall", "holiday", "workingday", "weathermist", "weatherrain/snow")], 2),
         title = "Rain or snow halves expected rentals; 2012 runs 56% above 2011",
         xlab = "Incidence-rate ratio (1 = no effect)", source = src)

#| **The overdispersion check.** If the Poisson assumption holds, the sum of squared Pearson residuals divided by the residual degrees of freedom is about 1. Here it is about 100: the counts vary about 100 times more than a Poisson model allows, even after weather and season.
dispersion <- sum(residuals(pois, type = "pearson")^2) / df.residual(pois)   # about 1 if Poisson fits
dispersion

#| **Fix 1: quasi-Poisson.** Same coefficients, but every standard error is multiplied by $\sqrt{\text{dispersion}}$, about 10. Plain Poisson standard errors were ten times too small, so its p-values were far too confident.
qp <- glm(f, family = quasipoisson, data = train)   # same fit, standard errors scaled up
# standard errors side by side for three coefficients: sqrt of the covariance diagonal
round(cbind(poisson_se = sqrt(diag(vcov(pois))), quasi_se = sqrt(diag(vcov(qp))))[c("yr", "weatherrain/snow", "temp10"), ], 4)

#| **Fix 2: negative binomial.** `MASS::glm.nb()` adds a parameter $\theta$ so that the variance is $\mu + \mu^2/\theta$: it grows with the square of the mean. A small $\theta$ means a lot of extra variation. The coefficients stay close to Poisson's, and the AIC drops enormously.
library(MASS)                              # for glm.nb()
nb <- glm.nb(f, data = train)              # negative binomial regression, same formula
c(theta = nb$theta, AIC_poisson = AIC(pois), AIC_negbin = AIC(nb))   # lower AIC = better fit
# IRRs from both models for three coefficients: nearly the same
round(cbind(poisson = exp(coef(pois)), negbin = exp(coef(nb)))[c("yr", "workingday", "weatherrain/snow"), ], 3)

#| **Where Poisson does fit: small counts.** At 4 a.m. on working days only a handful of bikes go out each hour. Fit a Poisson model with a year effect to those hours: the dispersion statistic is about 1.7. Not exactly 1, but nowhere near the 100 of the daily model. Small counts are Poisson's home turf; busy hours and whole days are not.
hourly <- read.csv("data/bike_hour.csv")   # one row per hour
early <- subset(hourly, hr == 4 & workingday == 1)   # 4 a.m. on working days only
pois4 <- glm(cnt ~ yr, family = poisson, data = early)
c(mean = mean(early$cnt), dispersion = sum(residuals(pois4, type = "pearson")^2) / df.residual(pois4))

#| **Exposure: not every day is a full day.** Counts depend on how long you were watching. The hourly file has a row only for hours with data, so we can count the hours recorded per day. On October 29, 2012 only one hour was recorded: Capital Bikeshare shut down for Hurricane Sandy. When exposure varies (hours open, stores, population), add `offset(log(exposure))` to the formula so the model predicts a *rate* per unit of exposure.
hours <- table(hourly$dteday)              # number of hourly rows (hours recorded) per date
hours[hours < 20]                          # days with fewer than 20 hours of data
