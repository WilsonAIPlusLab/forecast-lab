# Hidden check: compares the student's elasticity and percent effects with the truth.
_b = smf.ols("np.log(veh) ~ np.log(gas) + un + mr + chip", data=d).fit().params["np.log(gas)"]
_ok = all(k in globals() for k in ("b_gas", "pct_approx", "pct_exact")) and \
    abs(b_gas - _b) < 1e-8 and abs(pct_approx - 20 * _b) < 1e-6 and abs(pct_exact - 100 * (1.2 ** _b - 1)) < 1e-6
_cars = -d.veh.iloc[-1] * (1.2 ** _b - 1) * 1e6
check_that(_ok,
    f"Right. The elasticity is {_b:.3f}, so a 20% rise in gas goes with about {20 * _b:.2f}% fewer sales (exact: {100 * (1.2 ** _b - 1):.2f}%), holding jobs and rates fixed. On today's 16.0 million that is about {round(_cars, -3):,.0f} cars a year. Notice how small an elasticity of {_b:.3f} is: car demand is very inelastic to fuel prices in the short run, because people still need cars. For small changes the rule of thumb and the exact formula agree; for big ones (gas doubling) use the exact one.",
    "Check the blanks: the model needs np.log(gas) (not gas) so its coefficient is an elasticity; the rule of thumb multiplies by 20 (percent, not 0.20); the exact formula raises 1.20 to the power of the elasticity.")
