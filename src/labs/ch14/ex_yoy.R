library(forecast)                                # ets(), forecast()
y <- fred("RSXFSN", start = 2010) / 1000         # U.S. retail sales, $ billions per month, NOT seasonally adjusted
f <- forecast(ets(y, model = "MAM", damped = TRUE), h = 12)$mean   # ETS(M,Ad,M) point forecasts, next 12 months
fc <- as.numeric(f)                              # plain numbers, $ billions
months <- format(as.Date(ts_dates(f)), "%b %Y")  # labels such as "Dec 2026"

# Two comparisons a manager might hear
latest <- as.numeric(tail(y, 1))                 # the latest actual month
last_year <- as.numeric(tail(y, ______))         # blank: how many months back covers the same calendar months a year earlier
vs_latest <- 100 * (fc / latest - 1)             # % change from the latest month: mixes in the seasonal pattern
vs_last_year <- 100 * (fc / ______ - 1)          # blank: the values from the same months a year earlier

data.frame(month = months, forecast = round(fc, 1), vs_latest = round(vs_latest, 1), vs_last_year = round(vs_last_year, 1))
total_growth <- 100 * (sum(fc) / sum(______) - 1)    # blank: the 12 actual months to compare the forecast total with
dec <- which(substr(months, 1, 3) == "Dec")      # position of December in the forecast
sprintf("December sales should be about $%.1f billion, %.1f%% above last December (not %.0f%% above %s, which mostly reflects the holiday season). Over the next 12 months as a whole, sales should run %.1f%% above the last 12.",
        fc[dec], vs_last_year[dec], vs_latest[dec], format(as.Date(tail(ts_dates(y), 1)), "%B"), total_growth)
