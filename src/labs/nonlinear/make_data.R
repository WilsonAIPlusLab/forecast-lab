# Generates src/components/nonlinear/nldata.json for the chapter's explorables.
# Run from site/:  Rscript src/labs/nonlinear/make_data.R
# Every model here is the same as in the chapter's labs (same split, same formulas).
library(MASS); library(jsonlite)
setwd("public")
r4 <- function(x, d = 4) round(x, d)

# ---- bank: chapter model on the training clients, test-set predictions with/without duration
bank <- read.csv("data/bank_marketing.csv", stringsAsFactors = TRUE)
bank$yes <- as.integer(bank$y == "yes"); bank$poutcome <- relevel(bank$poutcome, ref = "nonexistent")
pos <- ave(seq_len(nrow(bank)), bank$y, FUN = seq_along) - 1; is_test <- pos %% 10 < 3
train <- bank[!is_test, ]; test <- bank[is_test, ]
f <- yes ~ age + contact + campaign + poutcome + euribor3m
logit <- glm(f, family = binomial, data = train)
leaky <- glm(update(f, . ~ . + duration), family = binomial, data = train)
p <- predict(logit, test, type = "response"); pd <- predict(leaky, test, type = "response")
xbar <- colMeans(model.matrix(logit))

# ---- bikes: forecast test with Poisson and negative binomial intervals
bikes <- read.csv("data/bike_day.csv"); bikes$date <- as.Date(bikes$dteday)
bikes$weather <- factor(bikes$weathersit, levels = 1:3, labels = c("clear", "mist", "rain/snow"))
bikes$season <- factor(bikes$season, levels = 1:4, labels = c("winter", "spring", "summer", "fall"))
bikes$temp10 <- 10 * bikes$temp
btr <- subset(bikes, date <= as.Date("2012-08-31")); bte <- subset(bikes, date > as.Date("2012-08-31"))
fb <- cnt ~ yr + season + holiday + workingday + weather + temp10 + I(temp10^2) + hum + windspeed
pois <- glm(fb, family = poisson, data = btr); nb <- glm.nb(fb, data = btr)
mp <- predict(pois, bte, type = "response"); mn <- predict(nb, bte, type = "response")
q <- function(a) list(pois = qpois(a, mp), nb = qnbinom(a, size = nb$theta, mu = mn))

# ---- hourly counts by working day x hour
hourly <- read.csv("data/bike_hour.csv")
hc <- lapply(0:1, function(w) lapply(0:23, function(h) hourly$cnt[hourly$workingday == w & hourly$hr == h]))

out <- list(
  bank = list(coef = as.list(r4(coef(logit), 6)), xbar = as.list(r4(xbar, 6)), base = mean(train$yes),
              test = list(p = r4(unname(p)), pd = r4(unname(pd)), y = test$yes)),
  bikes = list(date = format(bte$date), y = bte$cnt, weather = bte$weathersit, workingday = bte$workingday,
               mu_p = round(unname(mp), 2), mu_n = round(unname(mn), 2), theta = r4(nb$theta),
               lo80 = q(0.10), hi80 = q(0.90), lo95 = q(0.025), hi95 = q(0.975),
               naive = bikes$cnt[match(bte$date - 1, bikes$date)],
               hist_date = format(tail(btr$date, 61)), hist = tail(btr$cnt, 61)),
  hourly = list(working = hc[[2]], off = hc[[1]])
)
write_json(out, "../src/components/nonlinear/nldata.json", auto_unbox = TRUE, digits = NA)
cat("wrote nldata.json\n")
