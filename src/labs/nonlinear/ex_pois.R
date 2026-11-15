# Is the morning rush Poisson? Rentals at 8 a.m. on working days.
hourly <- read.csv("data/bike_hour.csv")   # one row per hour
rush <- subset(hourly, hr == 8 & workingday == 1)   # keep 8 a.m. on working days only

# 1. Fit a Poisson regression of the count on the year and the temperature
# blank: the glm() family for count data
m <- glm(cnt ~ yr + temp, family = ______, data = rush)

# 2. Dispersion statistic: sum of squared Pearson residuals / residual df
# blanks: the residual type named above, and the function giving the model's residual degrees of freedom
dispersion <- sum(residuals(m, type = "______")^2) / ______
dispersion                                 # about 1 if the Poisson assumption holds
