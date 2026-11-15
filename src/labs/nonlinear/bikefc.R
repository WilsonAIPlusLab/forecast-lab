#| **Set up the forecast test.** Fit on January 2011 to August 2012, then forecast each day of September to December 2012 (122 days) as if it were tomorrow. We give the model each test day's calendar and *actual* weather, which treats the weather forecast as perfect, so the intervals below are, if anything, too kind.
library(MASS)
bikes <- read.csv("data/bike_day.csv")
bikes$date <- as.Date(bikes$dteday)
bikes$weather <- factor(bikes$weathersit, levels = 1:3, labels = c("clear", "mist", "rain/snow"))
bikes$season <- factor(bikes$season, levels = 1:4, labels = c("winter", "spring", "summer", "fall"))
bikes$temp10 <- 10 * bikes$temp
train <- subset(bikes, date <= as.Date("2012-08-31"))
test  <- subset(bikes, date >  as.Date("2012-08-31"))
f <- cnt ~ yr + season + holiday + workingday + weather + temp10 + I(temp10^2) + hum + windspeed
pois <- glm(f, family = poisson, data = train)
nb   <- glm.nb(f, data = train)

#| **Point forecasts.** Both models give almost the same expected count $\hat\mu$ for each day, so their point accuracy is nearly identical. Compare with a naive benchmark (tomorrow = today, Chapter 3): the regressions win clearly.
mu_p <- predict(pois, newdata = test, type = "response")
mu_n <- predict(nb, newdata = test, type = "response")
naive <- bikes$cnt[match(test$date - 1, bikes$date)]
c(MAE_poisson = mean(abs(test$cnt - mu_p)), MAE_negbin = mean(abs(test$cnt - mu_n)), MAE_naive = mean(abs(test$cnt - naive)))

#| **Prediction intervals from the count distribution.** An 80% interval runs from the 10th to the 90th percentile of the predicted distribution. `qpois()` gives Poisson percentiles; `qnbinom(size = theta, mu = mu)` gives negative-binomial ones. (Simulating many draws with `rpois()`/`rnbinom()` and taking quantiles gives the same answer.) These intervals ignore the uncertainty in the estimated coefficients, which is small next to the day-to-day noise here.
interval <- function(level) {
  a <- (1 - level) / 2
  data.frame(pois_lo = qpois(a, mu_p), pois_hi = qpois(1 - a, mu_p),
             nb_lo = qnbinom(a, size = nb$theta, mu = mu_n), nb_hi = qnbinom(1 - a, size = nb$theta, mu = mu_n))
}
i80 <- interval(0.80); i95 <- interval(0.95)
head(cbind(date = format(test$date), actual = test$cnt, round(mu_p), i80), 5)

#| **The coverage audit.** A 95% interval should contain about 95% of actual outcomes. Count how often each one did. The Poisson intervals are only a few hundred bikes wide on days averaging more than 5,000 rentals, so reality falls outside almost every time.
covered <- function(lo, hi) mean(test$cnt >= lo & test$cnt <= hi)
audit <- data.frame(model = c("Poisson", "Negative binomial"),
  cover_80 = c(covered(i80$pois_lo, i80$pois_hi), covered(i80$nb_lo, i80$nb_hi)),
  cover_95 = c(covered(i95$pois_lo, i95$pois_hi), covered(i95$nb_lo, i95$nb_hi)),
  median_width_95 = c(median(i95$pois_hi - i95$pois_lo), median(i95$nb_hi - i95$nb_lo)))
audit

#| **See both fans.** Gold dots are what happened. The Poisson fan is a thin thread; the negative-binomial fan is wide enough to be honest most days. Hover the deep dip at the end of October: on October 29, 2012, Capital Bikeshare shut down for Hurricane Sandy. No count model saw that coming.
for (m in list(list("Poisson", mu_p, i80$pois_lo, i80$pois_hi, i95$pois_lo, i95$pois_hi),
               list("Negative binomial", mu_n, i80$nb_lo, i80$nb_hi, i95$nb_lo, i95$nb_hi))) {
  cov95 <- covered(m[[5]], m[[6]])
  viz_custom("nl-fan", date = format(test$date), actual = test$cnt,
             hist_date = format(tail(train$date, 61)), hist = tail(train$cnt, 61),
             mean = round(m[[2]]), lo80 = m[[3]], hi80 = m[[4]], lo95 = m[[5]], hi95 = m[[6]],
             title = sprintf("%s: the 95%% interval caught %.0f%% of days", m[[1]], 100 * cov95),
             subtitle = "Daily rentals, Sep–Dec 2012; bands = 80% and 95% prediction intervals",
             source = "UCI Bike Sharing (Fanaee-T & Gama 2013), CC BY 4.0")
}
