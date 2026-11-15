from statsmodels.tsa.exponential_smoothing.ets import ETSModel   # statsmodels' ETS (error, trend, seasonal) model
# Total retail & food services = motor vehicles & parts + everything else ($ millions, SA); one column per part
parts = pd.DataFrame({"Motor_vehicles": fred("RSMVPD", start=2015), "Ex_autos": fred("RSFSXMV", start=2015)})
total = fred("RSAFS", start=2015)                            # the published total, to compare against
train, test_total = parts[:"2025-09"], total["2025-10":]     # hide the last 12 months (slicing by date)

def damped_fc(y, h=12):                                      # helper used for every series; h = months ahead
    """Additive damped-trend ETS forecast (a fixed stand-in for R's automatic ets())."""
    return ETSModel(y, error="add", trend="add", damped_trend=True).fit(disp=False).forecast(h).values

# 1. Forecast each part 12 months ahead. Blank: the data the models are allowed to see (not the hidden months)
fc_parts = pd.DataFrame({c: damped_fc(______[c]) for c in parts.columns}, index=test_total.index)
# the {c: ... for c in ...} dict comprehension builds one forecast column per part

# 2. Bottom-up: add the parts month by month
# blank: the DataFrame method that adds values; axis=1 means across columns, row by row
bu_total = fc_parts.______(axis=1)

direct = damped_fc(total[:"2025-09"])                        # benchmark: the same method on the total directly
# mean absolute error of each approach over the 12 hidden months ($ millions; lower is better)
print({"bottom_up_MAE": round(float((test_total - bu_total).abs().mean())),
       "direct_MAE": round(float(np.abs(test_total.values - direct).mean()))})
