#| **Two ingredients**: nominal retail and food services sales (`RSAFS`, $ millions, SA) and CPI (`CPIAUCSL`, 1982–84 = 100, SA). We build CPI from its CSV so the missing October 2025 stays `NaN` (`fred()` would fill it by interpolation and invent one month of real sales).
nominal = fred("RSAFS")                       # nominal retail & food services sales, $ millions, SA
raw_cpi = pd.read_csv("data/CPIAUCSL.csv")    # CPI from the raw file, keeps the October 2025 NaN
cpi = pd.Series(raw_cpi["CPIAUCSL"].values, index=pd.to_datetime(raw_cpi["observation_date"]), name="CPIAUCSL").asfreq("MS")

#| **Deflate**: real = nominal / CPI × 100, in 1982–84 dollars. pandas aligns the two series on their dates; `dropna()` drops the months where either is missing (before 1992, and October 2025).
real = (nominal / cpi * 100).dropna()         # real sales in 1982-84 dollars (pandas matches months by date)
print(real.index[0].date())                   # first month where both series exist

#| **Check against FRED's own real series** (`RRSFS`) through 2024.
print(np.allclose(real[:"2024-12"], fred("RRSFS")[:"2024-12"], rtol=1e-5))   # True = equal up to rounding

#| **How much of the growth is real?** September 2026 versus the 2019 average.
def growth(s):                                # % change from the 2019 average to September 2026
    return 100 * (s["2026-09-01"] / s["2019"].mean() - 1)
g = {"nominal": growth(nominal), "prices": growth(cpi), "real": growth(real)}   # three growth rates
print({k: round(float(v), 1) for k, v in g.items()})   # dictionary comprehension: round each to one decimal

#| **Growth rates multiply**: (1 + nominal) = (1 + real)(1 + inflation). Subtracting overstates real growth.
# exact (divide growth factors) first, then the shortcut (subtract rates)
print(round(100 * ((1 + g["nominal"] / 100) / (1 + g["prices"] / 100) - 1), 1), round(g["nominal"] - g["prices"], 1))

#| **In today's dollars**: multiply by the latest CPI (September 2026).
real_now = real * cpi["2026-09-01"] / 100     # real sales in September-2026 dollars

#| **Index both to 2019 = 100.**
def base(s):                                  # rescale so the 2019 average = 100
    return 100 * s / s["2019"].mean()
viz_ts(Nominal=base(nominal)["2015":], Real=base(real_now)["2015":], ylab="index, 2019 average = 100",   # both from 2015 on
       title="Retail sales are up sharply since 2019, but mostly because prices are")
