"""Run every lab natively (R and Python), with hidden setups prepended and exercises run as solution + check.
Usage (from site/): python tools/check_all.py      Prints a summary and any failures."""
import glob, os, re, subprocess, tempfile, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
RS = r"C:\Program Files\R\R-4.4.3\bin\Rscript.exe"
SETUP = {"ch08": "setup", "ch12": "features_setup", "nonlinear": "setup_bank"}
SKIP = re.compile(r"(_check|setup|make_data|build_data|xgboost_lite)\.(R|py)$|/exercise\.(R|py)$|/ex_\w+?\.(R|py)$")
tmp = tempfile.mkdtemp()
results = []
for ext in ("R", "py"):
    for f in sorted(glob.glob(f"src/labs/*/*.{ext}")):
        f = f.replace("\\", "/")
        folder = f.split("/")[2]
        name = os.path.basename(f)
        if SKIP.search(f) and not name.startswith(("exercise_solution", "ex_logit_solution", "ex_pois_solution")):
            continue
        if folder == "nonlinear" and name == "activity.R":
            pass
        parts = []
        if folder in SETUP: parts.append(f"src/labs/{folder}/{SETUP[folder]}.{ext}")
        parts.append(f)
        if "solution" in name:
            chk = f.replace("_solution", "_check")
            if os.path.exists(chk): parts.append(chk)
        combined = os.path.join(tmp, f"{folder}__{name}")
        with open(combined, "w", encoding="utf8") as out:
            for p in parts: out.write(open(p, encoding="utf8").read() + "\n")
        rel = os.path.relpath(combined)
        cmd = [RS, "tools/check_lab.R", combined] if ext == "R" else [sys.executable, "tools/check_lab.py", combined]
        r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf8", errors="replace")
        line = [l for l in r.stdout.splitlines() if l.startswith("-> ")]
        ok = bool(line) and line[-1].startswith("-> OK")
        if "solution" in name and ok and '"pass": false' in r.stdout.replace("'", '"'):
            ok = False
        results.append((f, ok, line[-1] if line else r.stderr[-300:]))
bad = [x for x in results if not x[1]]
print(f"{len(results)} runs, {len(results) - len(bad)} OK, {len(bad)} failed")
for f, _, msg in bad: print("FAIL", f, "::", msg[:200])
