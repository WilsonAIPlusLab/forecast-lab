import warnings; warnings.filterwarnings("ignore")   # hide optimizer warnings
from statsmodels.tsa.exponential_smoothing.ets import ETSModel
import numpy as np
online = fred("MRTSSM4541USN", start=2015)       # U.S. e-commerce sales, $ millions, NSA
train = online[:"2025-08"]                       # same training data as the ETS lab
# ETS(M,A,M), the model R's ets() picks (statsmodels has no automatic search)
fit = ETSModel(train, error="mul", trend="add", seasonal="mul", seasonal_periods=12).fit(disp=False)
par = dict(zip(fit.param_names, fit.params))     # parameter name -> estimate

# 1. The level's smoothing parameter
# blank: statsmodels calls alpha "smoothing_" + the name of the state it smooths
alpha = par["______"]

# 2. Its half-life: months until a new observation's weight falls by half
# blank: the same formula as the explorer, log(0.5) / log(1 - something)
half_life = np.log(0.5) / np.log(1 - ______)

# 3. The slope at the end of the sample, in $ millions per month
# blank: the column of fit.states that holds the slope (the others are "level" and "seasonal")
slope = fit.states["______"].iloc[-1]            # .iloc[-1] = last row (August 2025)

print({"alpha": round(float(alpha), 3), "half_life": round(float(half_life), 3), "avg_age": round(float(1 / alpha), 3), "slope": round(float(slope), 1)})
