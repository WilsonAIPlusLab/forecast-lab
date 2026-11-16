# Hidden check for ex_window: refit both windows and compare the MAEs.
_fl, _fs = fit_ets(food[:"2025-08"]), fit_ets(food["2021":"2025-08"])
_ml, _ms = (test - _fl.forecast(12)).abs().mean(), (test - _fs.forecast(12)).abs().mean()
_ok = "mae" in globals() and isinstance(mae, dict) and abs(mae.get("long", 0) - _ml) < 1e-6 and abs(mae.get("short", 0) - _ms) < 1e-6
check_that(_ok,
  f"Starting in 2021 cuts the test MAE from about ${_ml:,.0f} million to ${_ms:,.0f} million a month. With 2020 inside the window, alpha is {alpha(_fl):.2f}: to survive the collapse, the level has to jump with every new month. From 2021, alpha drops to {alpha(_fs):.2f}, a calmer memory. (R's ets() picks a different model for each window but tells the same story.) Compare windows in dollars on the same test months, never by MASE, whose yardstick changes with the window.",
  "Check the blanks: the short window starts at \"2021\" (in quotes); the horizon is 12 (or len(test)); and the method is .mean().")
