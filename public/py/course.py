"""Forecast Lab course helpers for Python (loaded automatically in the browser).

fred(id)   -> pandas Series with a DatetimeIndex (bundled FRED data)
viz_*(...) -> send an interactive chart to the web page
"""
import json, io, base64, ast, hashlib
import numpy as np
import pandas as pd

__all__ = ["fred", "viz_ts", "viz_forecast", "viz_compare", "viz_table", "viz_bars",
           "viz_scatter", "viz_lines", "viz_acf", "viz_decomp", "viz_kpi", "viz_custom", "check_that", "np", "pd"]
_KEEP = set(__all__) | {"course"}
pd.set_option("display.width", 110)
pd.set_option("display.max_columns", 40)
pd.set_option("display.precision", 4)
_queue = []
_hash = {}
_src = []


def _source():
    return f"FRED, Federal Reserve Bank of St. Louis ({', '.join(_src)})" if _src else None


def check_that(cond, passed="Well done.", fail="Not quite yet. Try again."):
    """Exercise check: check_that(abs(x.mean() - 5) < 0.01, "Correct!", "Hint: ...")."""
    try:
        ok = bool(cond)
    except Exception:
        ok = False
    _push(dict(type="check", **{"pass": ok}, message=passed if ok else fail))
    return ok


def _clean(o):
    if isinstance(o, dict):
        return {k: _clean(v) for k, v in o.items()}
    if isinstance(o, (list, tuple)):
        return [_clean(v) for v in o]
    if isinstance(o, (np.floating, float)):
        return None if not np.isfinite(o) else float(o)
    if isinstance(o, np.integer):
        return int(o)
    if isinstance(o, np.ndarray):
        return _clean(o.tolist())
    if isinstance(o, (pd.Timestamp,)):
        return o.strftime("%Y-%m-%d")
    return o


def _push(spec):
    import inspect
    fr = inspect.currentframe().f_back
    if fr is not None and fr.f_locals.get("source") is not None:
        spec["source"] = fr.f_locals["source"]
    if spec.get("type") not in ("check", "kpi", "table") and "source" not in spec:
        spec["source"] = _source()
    _queue.append(_clean(spec))


def _viz_pop():
    global _queue
    s = json.dumps(_queue)
    _queue = []
    return s


def _flush_figs():
    import sys
    if "matplotlib.pyplot" not in sys.modules:
        return "[]"
    try:
        import matplotlib
        matplotlib.use("agg")
        import matplotlib.pyplot as plt
    except Exception:
        return "[]"
    out = []
    for n in plt.get_fignums():
        fig = plt.figure(n)
        buf = io.BytesIO()
        fig.savefig(buf, format="png", dpi=110, bbox_inches="tight")
        out.append(base64.b64encode(buf.getvalue()).decode())
    plt.close("all")
    return json.dumps(out)


def _repr(o):
    try:
        return repr(o.to_py()) if hasattr(o, "to_py") else repr(o)
    except Exception:
        return str(o)


# ── data ─────────────────────────────────────────────────────────
def fred(id, start=None, end=None, to=None, quiet=False):
    """Read a bundled FRED series as a pandas Series on its true calendar grid.

    Monthly/quarterly data: missing periods stay in place; gaps of 1-2 periods are filled by
    linear interpolation (with a note); older stretches with longer gaps are dropped.
    Daily data is returned as-is (pandas handles dates); pass to="month" or "quarter" to aggregate.
    """
    if id in _src:
        _src.remove(id)
    _src.insert(0, id)
    del _src[6:]
    df = pd.read_csv(f"data/{id}.csv", na_values=[".", ""])
    s = pd.Series(df.iloc[:, 1].values, index=pd.to_datetime(df.iloc[:, 0]), name=id).dropna()
    if to:
        s = s.resample({"month": "MS", "M": "MS", "quarter": "QS", "Q": "QS"}.get(to, to)).mean()
    gap = s.index.to_series().diff().dt.days.median()
    if gap > 25:
        f = "YS" if gap > 300 else "QS" if gap > 80 else "MS"
        s = s.asfreq(f)
    elif gap > 5:
        s = s.asfreq("7D")
    if start is not None:
        s = s[s.index >= pd.Timestamp(str(start))]
    if end is not None:
        s = s[s.index <= pd.Timestamp(str(end))]
    if gap > 5 and s.isna().any():
        na = s.isna()
        runs = (na != na.shift()).cumsum()
        lengths = na.groupby(runs).transform("sum")
        long = na if na.sum() > 3 else (na & (lengths > 2))  # many gaps: don't invent data
        if long.any():
            cut = long[long].index[-1]
            s = s[s.index > cut]
            if not quiet:
                print(f"Note: {id} has gaps before {s.index[0].date()}; the series starts there.")
        s = s.loc[s.first_valid_index():s.last_valid_index()]
        if s.isna().any():
            if not quiet:
                print(f"Note: {id} has no value for {', '.join(str(d.date()) for d in s.index[s.isna()])} "
                      "(e.g. the 2025 government shutdown); filled by linear interpolation.")
            s = s.interpolate()
    return s


def _ser(s, name="series"):
    s = pd.Series(s)
    idx = s.index
    dates = [pd.Timestamp(d).strftime("%Y-%m-%d") for d in idx] if isinstance(idx, pd.DatetimeIndex) else [str(i) for i in idx]
    return {"name": str(name), "date": dates, "value": s.astype(float).tolist()}


# ── charts ───────────────────────────────────────────────────────
def viz_ts(*series, title=None, subtitle=None, ylab=None, recessions=False, facet=False, log=False, source=None, **named):
    items = [_ser(s, getattr(s, "name", None) or f"series{i+1}") for i, s in enumerate(series)]
    items += [_ser(s, k) for k, s in named.items()]
    rec = None
    if recessions:
        r = pd.read_csv("data/USREC.csv")
        rec = r[r.iloc[:, 1] == 1].iloc[:, 0].tolist()
    _push(dict(type="ts", title=title, subtitle=subtitle, ylab=ylab, series=items, recessions=rec, facet=facet, log=log))


def viz_forecast(history, mean, lower=None, upper=None, actual=None, title=None, subtitle=None, method=None, levels=("95%",), fitted=None, from_=None, source=None):
    """history/mean/actual: Series. lower/upper: Series or list of Series (one per level)."""
    if from_ is not None:
        history = history[history.index >= pd.Timestamp(str(from_))]
    spec = dict(type="forecast", title=title or method, subtitle=subtitle, method=method,
                history=_ser(history, "history"), mean=_ser(mean, "forecast"))
    if lower is not None:
        lo = lower if isinstance(lower, (list, tuple)) else [lower]
        hi = upper if isinstance(upper, (list, tuple)) else [upper]
        spec["bands"] = [dict(level=levels[i] if i < len(levels) else "", lo=pd.Series(lo[i]).astype(float).tolist(), hi=pd.Series(hi[i]).astype(float).tolist()) for i in range(len(lo))]
    if actual is not None:
        spec["actual"] = _ser(actual, "actual")
    if fitted is not None:
        spec["fitted"] = _ser(fitted, "fitted")
    _push(spec)


def viz_compare(history=None, actual=None, title=None, subtitle=None, source=None, **models):
    _push(dict(type="compare", title=title, subtitle=subtitle,
               history=_ser(history, "history") if history is not None else None,
               actual=_ser(actual, "actual") if actual is not None else None,
               models=[_ser(v, k) for k, v in models.items()]))


def viz_table(df, title=None, subtitle=None, highlight=None, digits=3, lower_is_better=True, source=None):
    df = pd.DataFrame(df)
    if not isinstance(df.index, pd.RangeIndex):
        df = df.reset_index().rename(columns={"index": "Model"})
    df = df.round(digits)
    _push(dict(type="table", title=title, subtitle=subtitle, columns=[str(c) for c in df.columns],
               rows=df.astype(object).where(pd.notna(df), None).values.tolist(), highlight=highlight, lower_is_better=lower_is_better))


def viz_bars(values, labels=None, title=None, subtitle=None, xlab=None, sort=True, highlight=None, source=None):
    s = pd.Series(values)
    _push(dict(type="bars", title=title, subtitle=subtitle, xlab=xlab, labels=[str(l) for l in (labels if labels is not None else s.index)],
               values=s.astype(float).tolist(), sort=sort, highlight=highlight))


def viz_scatter(x, y, title=None, subtitle=None, xlab=None, ylab=None, fit=True, labels=None, source=None):
    _push(dict(type="scatter", title=title, subtitle=subtitle, xlab=xlab or getattr(x, "name", "x"), ylab=ylab or getattr(y, "name", "y"),
               x=pd.Series(x).astype(float).tolist(), y=pd.Series(y).astype(float).tolist(), fit=fit, labels=labels))


def viz_lines(x, title=None, subtitle=None, xlab=None, ylab=None, zero=False, source=None, **ys):
    _push(dict(type="lines", title=title, subtitle=subtitle, xlab=xlab, ylab=ylab, zero=zero, x=list(np.asarray(x, dtype=float)),
               series=[dict(name=k, value=list(np.asarray(v, dtype=float))) for k, v in ys.items()]))


def viz_acf(x, lag_max=36, kind="acf", title=None, source=None):
    from statsmodels.tsa.stattools import acf, pacf
    x = pd.Series(x).dropna()
    v = acf(x, nlags=lag_max) if kind == "acf" else pacf(x, nlags=lag_max)
    _push(dict(type="acf", kind=kind.upper(), title=title, lag=list(range(1, lag_max + 1)), value=list(v[1:]), ci=1.96 / np.sqrt(len(x))))


def viz_decomp(res, title=None, source=None):
    """res: statsmodels STL(...).fit() or seasonal_decompose(...) result."""
    parts = {"data": res.observed, "trend": res.trend, "seasonal": res.seasonal, "remainder": res.resid}
    _push(dict(type="decomp", title=title, parts=[_ser(v, k) for k, v in parts.items()]))


def viz_kpi(title=None, **items):
    _push(dict(type="kpi", title=title, items=[dict(label=k, value=v) for k, v in items.items()]))


def viz_custom(type, **kw):
    _push(dict(type=type, **kw))


# ── step-through support ────────────────────────────────────────
def _parse_steps(src):
    tree = ast.parse(src)
    return json.dumps([{"start": n.lineno, "end": n.end_lineno} for n in tree.body])


def _fp(x):
    try:
        if isinstance(x, (pd.Series, pd.DataFrame)):
            return hashlib.md5(pd.util.hash_pandas_object(x, index=True).values.tobytes()).hexdigest()
        if isinstance(x, np.ndarray):
            return hashlib.md5(x.tobytes()).hexdigest()
        return hashlib.md5(repr(x).encode()).hexdigest()
    except Exception:
        return str(id(x))


def _inspect(g):
    import types
    out = []
    names = [k for k in g if not k.startswith("_") and k not in _KEEP and not isinstance(g[k], types.ModuleType)]
    seen = {}
    for n in names:
        x = g[n]
        if callable(x) and not hasattr(x, "predict"):
            continue
        h = _fp(x); seen[n] = h
        status = "new" if n not in _hash else ("changed" if _hash[n] != h else "same")
        info = {"name": n, "class": type(x).__name__, "status": status}
        if isinstance(x, pd.Series):
            info["summary"] = f"Series [{len(x)}] {x.index[0]} – {x.index[-1]}" if len(x) else "Series (empty)"
            v = x.astype(float, errors="ignore") if x.dtype != object else None
            if v is not None and len(v) > 1:
                arr = np.asarray(v, dtype=float)
                if len(arr) > 400:
                    arr = arr[np.linspace(0, len(arr) - 1, 400).astype(int)]
                info["spark"] = _clean(arr)
        elif isinstance(x, pd.DataFrame):
            hd = x.head(5).reset_index()
            info["summary"] = f"DataFrame [{x.shape[0]} rows × {x.shape[1]} cols]"
            info["table"] = {"columns": [str(c) for c in hd.columns], "rows": _clean([[str(v) if not isinstance(v, (int, float, np.number)) else (float(np.round(v, 5)) if np.isfinite(v) else None) for v in r] for r in hd.values.tolist()])}
        elif isinstance(x, np.ndarray):
            info["summary"] = f"ndarray {x.shape}"
            if x.ndim == 1 and len(x) > 5 and np.issubdtype(x.dtype, np.number):
                info["spark"] = _clean(x[np.linspace(0, len(x) - 1, min(400, len(x))).astype(int)].astype(float))
        elif isinstance(x, (int, float, str, bool, np.number)):
            info["summary"] = f"{type(x).__name__}: {x!r}"[:120]
        elif isinstance(x, (list, tuple, dict)):
            info["summary"] = f"{type(x).__name__} (length {len(x)})"
        else:
            info["summary"] = type(x).__name__
        out.append(info)
    _hash.clear(); _hash.update(seen)
    return json.dumps(_clean(out))
