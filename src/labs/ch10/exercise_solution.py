import warnings; warnings.filterwarnings("ignore")
from statsmodels.tsa.exponential_smoothing.ets import ETSModel
clothing = fred("MRTSSM448USN", start=2022)            # U.S. clothing stores, $ millions, NSA
last = clothing.index[-1]
h = (2026 - last.year) * 12 + (12 - last.month)          # months ahead to December 2026
fit = ETSModel(clothing, error="add", trend="add", seasonal="add", seasonal_periods=12,
               initialization_method="heuristic").fit(disp=False)
np.random.seed(1)
demand = fit.simulate(h, repetitions=5000, anchor="end").iloc[-1].values

# A discount chain: thin margins, heavy markdowns on leftovers
cu = 0.30   # cost of each $1 of demand you cannot serve
co = 0.45   # cost of each $1 of stock left over

# 1. The critical ratio (the service level the costs justify)
cr = cu / (cu + co)

# 2. The optimal stock: the demand quantile at the critical ratio
stock = np.quantile(demand, cr)
print(round(cr, 2), round(stock), round(np.median(demand)))
