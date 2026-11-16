"""Measure how much is in each chapter's main path (everything before the "Beyond the basics" box and the instructor kit).
Usage (from site/): python tools/density.py [slug ...]   Compare with the budgets in TRIM.md."""
import glob, os, re, sys

def measure(path):
    s = open(path, encoding="utf8").read()
    body = s.split("<InstructorKit")[0].split("<BeyondBasics")[0]
    body = re.sub(r"^---.*?^---", "", body, count=1, flags=re.S | re.M)   # frontmatter
    body = re.sub(r"^import .*$", "", body, flags=re.M)
    labs = len(re.findall(r"<CodeLab\b", body))
    ex = len(re.findall(r"<CodeLab\b[^>]*\bexercise\b", body, flags=re.S))
    preds = len(re.findall(r"<Predict\b", body))
    emp = body.count('type="empirical"')
    tags = re.findall(r"<([A-Z]\w+)\s+client:load", body)
    exps = sum(1 for t in tags if t not in ("CodeLab", "Predict"))
    text = re.sub(r"<[^>]+>", " ", body)
    words = len(re.findall(r"[A-Za-z]+", text))
    return words, labs, ex, exps, preds, emp

slugs = sys.argv[1:]
files = [f"src/pages/chapters/{s}.mdx" for s in slugs] if slugs else sorted(glob.glob("src/pages/chapters/*.mdx"))
print(f"{'chapter':26s} {'words':>6s} {'labs':>5s} {'ex':>3s} {'explor':>7s} {'predict':>8s} {'empirical':>10s}")
for f in files:
    w, l, e, x, p, m = measure(f)
    print(f"{os.path.basename(f)[:-4]:26s} {w:6d} {l:5d} {e:3d} {x:7d} {p:8d} {m:10d}")
