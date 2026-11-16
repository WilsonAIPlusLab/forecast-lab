"""Refresh every bundled FRED series and rebuild public/data/manifest.json.
Usage (from site/): python tools/update_data.py          (DIVISIA_M4 is not from FRED and is left as-is)"""
import csv, json, os, urllib.request
D = os.path.join("public", "data")
NON_FRED = {"DIVISIA_M4", "bank_marketing"}
OLD = json.load(open(os.path.join(D, "manifest.json")))
for f in sorted(os.listdir(D)):
    if f.endswith(".csv") and f[:-4] not in NON_FRED:
        sid = f[:-4]
        try:
            data = urllib.request.urlopen(f"https://fred.stlouisfed.org/graph/fredgraph.csv?id={sid}", timeout=60).read()
            open(os.path.join(D, f), "wb").write(data); print("updated", sid)
        except Exception as e:
            print("FAILED", sid, e)
m = {}
for f in sorted(os.listdir(D)):
    if f.endswith(".csv"):
        rows = list(csv.reader(open(os.path.join(D, f))))
        vals = [r for r in rows[1:] if len(r) > 1 and r[1] not in ("", ".")]
        k = f[:-4]
        if OLD.get(k, {}).get("lazy"):
            m[k] = {**OLD[k], "n": len(rows) - 1}
        else:
            m[k] = {"file": f, "cols": rows[0], "n": len(rows) - 1, "start": vals[0][0], "end": vals[-1][0]}
json.dump(m, open(os.path.join(D, "manifest.json"), "w"), indent=1)
print(len(m), "series in manifest")
