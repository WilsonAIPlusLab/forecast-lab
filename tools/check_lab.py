"""Usage (from site/): python tools/check_lab.py [--setup src/labs/chNN/setup.py] src/labs/chNN/lab.py [...]
Runs each lab like the browser does (course helpers + bundled data, optional hidden setup first)."""
import sys, os, json, time, re, traceback, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
root = os.path.abspath(".")
sys.path.insert(0, os.path.join(root, "public", "py"))
import matplotlib; matplotlib.use("agg")

args = sys.argv[1:]
setup = None
if "--setup" in args:
    k = args.index("--setup"); setup = args[k + 1]; del args[k:k + 2]

def strip(path):
    return "\n".join(l for l in open(os.path.join(root, path), encoding="utf8").read().splitlines() if not re.match(r"^\s*#\|", l))

for f in args:
    print(f"\n==== {f} ====")
    os.chdir(os.path.join(root, "public"))
    import importlib, course; importlib.reload(course)
    g = {"__name__": "__main__"}
    exec("from course import *", g)
    t0 = time.time(); ok = True
    try:
        if setup:
            exec(compile(strip(setup), setup, "exec"), g)
        exec(compile(strip(f), f, "exec"), g)
    except Exception:
        ok = False; traceback.print_exc()
    viz = json.loads(course._viz_pop())
    for v in viz:
        if v.get("type") == "check": print(f"CHECK {'PASS' if v.get('pass') else 'FAIL'}: {v.get('message')}")
    print(f"\n-> {'OK' if ok else 'FAILED'} in {time.time()-t0:.1f}s; {len(viz)} chart(s): " + "; ".join(v['type'] + (f" '{v.get('title')}'" if v.get('title') else '') for v in viz))
    os.chdir(root)
