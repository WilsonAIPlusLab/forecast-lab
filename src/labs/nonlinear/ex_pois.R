# Is the morning rush Poisson? Rentals at 8 a.m. on working days.
hourly <- read.csv("data/bike_hour.csv")
rush <- subset(hourly, hr == 8 & workingday == 1)

# 1. Fit a Poisson regression of the count on the year and the temperature
m <- glm(cnt ~ yr + temp, family = ______, data = rush)

# 2. Dispersion statistic: sum of squared Pearson residuals / residual df
dispersion <- sum(residuals(m, type = "______")^2) / ______
dispersion
