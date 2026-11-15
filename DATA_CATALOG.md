# Bundled data catalog (public/data/*.csv, all from FRED®, Federal Reserve Bank of St. Louis)

Load in R with `fred("ID")` (returns a `ts` on the true calendar grid; daily series are averaged to monthly by default; 1–2-period gaps such as the Oct-2025 shutdown month are linearly interpolated with a printed note), in Python with `fred("ID")` (pandas Series), in JS explorables with `loadSeries("ID", { to: 'month' })` from `src/lib/ts.ts`.
SA = seasonally adjusted, NSA = not seasonally adjusted. **Always state SA/NSA correctly in prose** — e.g. MRTSSM4541USS is SA (no seasonality left), RSXFSN is NSA (strong December peak).

| ID | Series | Freq | Units | Adj. |
|---|---|---|---|---|
| RSXFSN | Retail sales, total excl. food services | M | $ millions | NSA |
| RSAFS | Advance retail & food services sales | M | $ millions | SA |
| RRSFS | Real retail & food services sales | M | $ millions, deflated by CPI (1982–84 $) | SA |
| MRTSSM4541USS | E-commerce (electronic shopping & mail-order) sales | M | $ millions | SA |
| MRTSSM4541USN | same, NSA | M | $ millions | NSA |
| MRTSSM441USN … MRTSSM722USN | Retail by NAICS category: 441 motor vehicles & parts, 442 furniture, 443 electronics & appliances, 444 building materials, 445 food & beverage stores, 446 health & personal care, 447 gasoline stations, 448 clothing, 451 sporting goods/hobby/books, 452 general merchandise, 453 misc. store retailers, 454 nonstore retailers, 722 food services & drinking places | M | $ millions | NSA |
| RSFSDP, RSGASS, RSCCAS, RSDBS, RSHPCS, RSNSR, RSGMS, RSFHFS, RSEAS, RSMVPD, RSFSXMV | Retail by category (food svcs & drinking, gas stations, clothing, building materials, health, nonstore, general merch, furniture, electronics, motor vehicles, total excl. motor vehicles) | M | $ millions | SA |
| UNRATE | Unemployment rate | M | % | SA |
| UNEMPLOY | Unemployed persons | M | thousands | SA |
| PAYEMS | Total nonfarm payroll employment | M | thousands | SA |
| CIVPART | Labor force participation rate | M | % | SA |
| JTSJOL | Job openings (JOLTS) | M | thousands | SA |
| AWHMAN | Avg weekly hours, manufacturing | M | hours | SA |
| ICSA | Initial jobless claims | W (Sat) | number | SA |
| CCSA | Continued claims | W | number | SA |
| IAUR | Iowa unemployment rate | M | % | SA |
| IANA | Iowa nonfarm employment | M | thousands | SA |
| CPIAUCSL | CPI-U all items | M | index 1982–84=100 | SA |
| CPILFESL | Core CPI (less food & energy) | M | index | SA |
| CPIUFDSL | CPI food | M | index | SA |
| PCEPILFE | Core PCE price index | M | index 2017=100 | SA |
| PPIACO | PPI all commodities | M | index 1982=100 | NSA |
| INDPRO | Industrial production index | M | index 2017=100 | SA |
| IPG2211A2N | Industrial production: electric & gas utilities | M | index | NSA (strong seasonality) |
| HOUST | Housing starts | M | thousands, SAAR | SA |
| HOUSTNSA | Housing starts | M | thousands | NSA |
| PERMIT | Building permits | M | thousands, SAAR | SA |
| TOTALSA | Light vehicle sales | M | millions, SAAR | SA |
| TOTALNSA | Light vehicle sales | M | thousands | NSA |
| PCE | Personal consumption expenditures | M | $ billions, SAAR | SA |
| DSPIC96 | Real disposable personal income | M | chained 2017 $ billions | SA |
| UMCSENT | U. Michigan consumer sentiment | M | index 1966:Q1=100 | NSA |
| GDPC1 | Real GDP | Q | chained 2017 $ billions | SA |
| A191RL1Q225SBEA | Real GDP growth | Q | % change, annualized | SA |
| GDPNOW | Atlanta Fed GDPNow (latest nowcast per quarter) | Q | % annualized | — |
| FEDFUNDS | Effective federal funds rate | M | % | — |
| TB3MS | 3-month Treasury bill | M | % | — |
| GS10 | 10-year Treasury | M | % | — |
| T10Y3M | 10y minus 3m Treasury spread | D | pct. points | — |
| T10Y2Y | 10y minus 2y spread | D | pct. points | — |
| BAA10Y | Moody's Baa minus 10y Treasury | D | pct. points | — |
| MORTGAGE30US | 30-year mortgage rate | W (Thu) | % | — |
| NFCI | Chicago Fed financial conditions index | W | index | — |
| USREC | NBER recession indicator | M | 1 = recession | — |
| M2SL | M2 money stock | M | $ billions | SA |
| DIVISIA_M4 | Divisia M4 incl. Treasuries (CFS) level & YoY growth | M | index / rate | — |
| GASREGW | Regular gasoline price | W (Mon) | $/gallon | NSA |
| DCOILWTICO | WTI crude oil | D | $/barrel | NSA |
| EXUSEU | US $ per euro | M | $ | — |

## Non-FRED teaching datasets (loaded lazily: the runtime fetches them when a lab mentions `data/<file>.csv`)

Read with `read.csv("data/bank_marketing.csv")` (R) or `pd.read_csv("data/bank_marketing.csv")` (Python); `fred()` is for FRED series only.

| File | Dataset | Rows | Notes |
|---|---|---|---|
| bank_marketing.csv | UCI Bank Marketing, *bank-additional* 10% sample (Moro, Cortez & Rita 2014), CC BY 4.0 | 4,119 clients | Portuguese bank phone campaigns, May 2008–Nov 2010. Target `y` = subscribed a term deposit (yes 11%). Columns renamed with `_` instead of `.` (emp_var_rate, cons_price_idx, cons_conf_idx, euribor3m, nr_employed). **`duration` (call length) is only known after the call: using it to predict `y` is leakage.** `pdays = 999` means never contacted before. |
| bike_day.csv | UCI Bike Sharing, Capital Bikeshare (Washington DC) daily, 2011–2012 (Fanaee-T & Gama 2013), CC BY 4.0 | 731 days | `cnt` = total rentals (casual + registered); `temp`, `atemp`, `hum`, `windspeed` are normalized to roughly 0–1. The dataset's Readme says temp = °C/41, atemp = °C/50, hum = %/100, windspeed = /67, while the UCI web page describes a min-max scaling (temp from −8 to 39 °C); treat them as indexes and say so if you convert to °C; `weathersit` 1 clear … 4 heavy rain; season 1 = winter. |
| bike_hour.csv | Same, hourly | 17,379 hours | `hr` 0–23; counts are small overnight (good for Poisson), large at rush hour. |
