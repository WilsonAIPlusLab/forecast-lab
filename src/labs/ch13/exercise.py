from statsmodels.tsa.exponential_smoothing.ets import ETSModel
# Total retail & food services = motor vehicles & parts + everything else ($ millions, SA)
parts = pd.DataFrame({"Motor_vehicles": fred("RSMVPD", start=2015), "Ex_autos": fred("RSFSXMV", start=2015)})
total = fred("RSAFS", start=2015)
train, test_total = parts[:"2025-09"], total["2025-10":]     # hide the last 12 months

def damped_fc(y, h=12):
    """Additive damped-trend ETS forecast (a fixed stand-in for R's automatic ets())."""
    return ETSModel(y, error="add", trend="add", damped_trend=True).fit(disp=False).forecast(h).values

# 1. Forecast each part 12 months ahead
fc_parts = pd.DataFrame({c: damped_fc(______[c]) for c in parts.columns}, index=test_total.index)

# 2. Bottom-up: add the parts month by month
bu_total = fc_parts.______(axis=1)

direct = damped_fc(total[:"2025-09"])
print({"bottom_up_MAE": round(float((test_total - bu_total).abs().mean())),
       "direct_MAE": round(float(np.abs(test_total.values - direct).mean()))})
