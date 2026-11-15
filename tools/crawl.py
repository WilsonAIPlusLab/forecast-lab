"""Crawl a built site folder and report broken internal links/anchors.
Usage (from site/): python tools/crawl.py dist [/base/]"""
import os, re, sys, html
from urllib.parse import urlparse, unquote
root = sys.argv[1]; base = sys.argv[2] if len(sys.argv) > 2 else '/'
pages = {}
for d, _, fs in os.walk(root):
    for f in fs:
        if f.endswith('.html'):
            p = os.path.join(d, f)
            pages[p] = open(p, encoding='utf8').read()
ids = {p: set(re.findall(r'\sid="([^"]+)"', t)) for p, t in pages.items()}
def resolve(href):
    u = urlparse(href)
    path = unquote(u.path)
    if not path.startswith(base): return None, 'outside base'
    rel = path[len(base):]
    fp = os.path.join(root, rel)
    if rel == '' or rel.endswith('/'): fp = os.path.join(fp, 'index.html')
    if os.path.isdir(fp): fp = os.path.join(fp, 'index.html')
    return fp, None
bad = []; n = 0
for p, t in pages.items():
    for attr, href in re.findall(r'\s(href|src)="([^"]+)"', t):
        href = html.unescape(href)
        if href.startswith(('http://', 'https://', 'mailto:', 'data:', 'javascript:')) or href.startswith('//'): continue
        n += 1
        if href.startswith('#'):
            if href[1:] and href[1:] not in ids[p]: bad.append((p, href, 'missing anchor'))
            continue
        fp, err = resolve(href)
        if err: bad.append((p, href, err)); continue
        if not os.path.exists(fp): bad.append((p, href, 'missing file')); continue
        frag = urlparse(href).fragment
        if frag and fp.endswith('.html') and frag not in ids.get(os.path.normpath(fp), ids.get(fp, set())):
            if frag not in set(re.findall(r'\sid="([^"]+)"', open(fp, encoding='utf8').read())):
                bad.append((p, href, 'missing anchor in target'))
print(f'{len(pages)} pages, {n} internal links checked, {len(bad)} problems')
for b in bad[:40]: print(' ', os.path.relpath(b[0], root), '->', b[1], '::', b[2])
