#| **Open the raw file first.** Every bundled series is a plain CSV downloaded from FRED: a date column and a value column. `pd.read_csv()` gives you a DataFrame. Look at the `dtypes`: the date column arrives as text (`object`, or `str` in pandas 3), so pandas does not know yet that this is a time series.
raw = pd.read_csv("data/UNRATE.csv")
print(raw.head(3))
print(raw.dtypes)

#| **Make the dates the index.** In pandas, a time series is a `Series` whose index is a **`DatetimeIndex`**. `pd.to_datetime()` parses the text dates; `asfreq("MS")` declares the frequency (*month start*), the pandas equivalent of R's `frequency = 12`.
unrate = pd.Series(raw["UNRATE"].values, index=pd.to_datetime(raw["observation_date"]), name="UNRATE").asfreq("MS")

#| **Ask the series about itself.** First date, last date, frequency, number of observations. Run these on every new series.
print(unrate.index[0].date(), unrate.index[-1].date(), unrate.index.freqstr, len(unrate))

#| **Cut out a time window.** With a `DatetimeIndex` you slice by date strings, and both ends are included. January 2019 to December 2021 spans the COVID spike to 14.8% in April 2020.
covid = unrate["2019-01":"2021-12"]
print(covid.max(), covid.idxmax().date())

#| **A month that does not exist.** October 2025 is blank (`NaN`): the federal government shut down from October 1 to November 12, 2025, and the household survey was never collected that month. Keep the `NaN` in place. Dropping the row would leave a hole in the index, and anything that counts rows (like `shift(12)`) would compare the wrong months.
print(unrate[unrate.isna()])
print(unrate["2025-08":"2025-12"])

#| **`fred()` does the loading in one line.** On payroll jobs (no gaps) the hand-built series and `fred()` are identical. On `UNRATE`, `fred()` prints a **Note** and fills October 2025 by *linear interpolation* (the average of its neighbors), because most models cannot handle `NaN`. Convenient for modeling, but the filled value is an estimate, not published data. When you need to know what was actually published, read the CSV as above.
raw_pay = pd.read_csv("data/PAYEMS.csv")
pay = pd.Series(raw_pay["PAYEMS"].values, index=pd.to_datetime(raw_pay["observation_date"]), name="PAYEMS").asfreq("MS")
print(pay.equals(fred("PAYEMS")))
print(fred("UNRATE")["2025-08":"2025-12"])

#| **Five vital signs of the economy**, each in the form analysts quote it: the unemployment rate as a level, the rest as percent change from a year earlier. `s.shift(12)` moves a monthly series down 12 rows; GDP is quarterly, so its year-ago shift is 4. We divide by hand rather than call `pct_change()`, which would quietly fill the gap. CPI has the same October 2025 gap as unemployment, so we build it from its CSV too: we do not want an inflation rate that rests on an interpolated month.
def yoy(s, k=12):
    return 100 * (s / s.shift(k) - 1)
raw_cpi = pd.read_csv("data/CPIAUCSL.csv")
cpi = pd.Series(raw_cpi["CPIAUCSL"].values, index=pd.to_datetime(raw_cpi["observation_date"]), name="CPIAUCSL").asfreq("MS")
infl = yoy(cpi)
jobs = yoy(pay)
ip   = yoy(fred("INDPRO"))
gdp  = yoy(fred("GDPC1"), 4)

#| **Label each panel with its latest reading**, computed from the data. `last_valid_index()` skips the trailing `NaN`: October 2026 inflation cannot be computed because it needs the missing October 2025 price level.
def latest(name, s, unit):
    d = s.last_valid_index()
    when = f"{d.year} Q{d.quarter}" if s.index.freqstr.startswith("Q") else d.strftime("%b %Y")
    return f"{name}: {s[d]:.1f}{unit} in {when}"
panels = {latest("Unemployment rate", unrate, "%"): unrate,
          latest("CPI inflation, y/y", infl, "%"): infl,
          latest("Payroll jobs, y/y", jobs, "%"): jobs,
          latest("Industrial production, y/y", ip, "%"): ip,
          latest("Real GDP, y/y", gdp, "%"): gdp}
print(list(panels))

#| **The economy at a glance**: one panel per series, gray bands for NBER recessions.
viz_ts(**{k: v["2000":] for k, v in panels.items()}, facet=True, recessions=True,
       title="The U.S. economy at a glance, 2000 to today")
