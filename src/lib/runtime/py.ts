// Pyodide (CPython compiled to WebAssembly) — one shared Python session per page.
import { setStatus, BASE } from './status';
import type { RunOutput } from './r';

const PYODIDE_URL = 'https://cdn.jsdelivr.net/pyodide/v314.0.8/full/';
let py: any = null;
let initPromise: Promise<any> | null = null;
let queue: Promise<any> = Promise.resolve();
const loaded = new Set<string>();
let lazyFiles = new Set<string>();
const fetchedLazy = new Set<string>();
async function ensureLazyData(code: string) {
  const want = [...code.matchAll(/data\/([A-Za-z0-9_]+\.csv)/g)].map((m) => m[1]).filter((f) => lazyFiles.has(f) && !fetchedLazy.has(f));
  for (const f of want) {
    const buf = new Uint8Array(await (await fetch(BASE + 'data/' + f)).arrayBuffer());
    py.FS.writeFile('/home/pyodide/data/' + f, buf);
    fetchedLazy.add(f);
  }
}
function serial<T>(fn: () => Promise<T>): Promise<T> { const p = queue.then(fn, fn); queue = p.catch(() => {}); return p; }

async function init() {
  setStatus('py', { state: 'loading', message: 'Downloading Python (≈10 MB, cached after first visit)…', progress: 0.05 });
  const { loadPyodide } = await import(/* @vite-ignore */ PYODIDE_URL + 'pyodide.mjs');
  py = await loadPyodide({ indexURL: PYODIDE_URL });
  setStatus('py', { message: 'Loading numpy & pandas…', progress: 0.3 });
  await py.loadPackage(["numpy", "pandas"], { messageCallback: () => {} });
  loaded.add("numpy"); loaded.add("pandas");
  setStatus('py', { message: 'Loading course data…', progress: 0.7 });
  const manifest = await (await fetch(BASE + 'data/manifest.json')).json();
  try { py.FS.mkdir('/home/pyodide/data'); } catch {}
  lazyFiles = new Set(Object.values(manifest).filter((m: any) => m.lazy).map((m: any) => m.file));
  await Promise.all(Object.values(manifest).filter((m: any) => !m.lazy).map(async (m: any) => {
    const buf = new Uint8Array(await (await fetch(BASE + 'data/' + m.file)).arrayBuffer());
    py.FS.writeFile('/home/pyodide/data/' + m.file, buf);
  }));
  const helper = await (await fetch(BASE + 'py/course.py')).text();
  py.FS.writeFile('/home/pyodide/course.py', helper);
  await py.runPythonAsync('import os, sys; os.chdir("/home/pyodide"); sys.path.insert(0, "/home/pyodide"); import course; from course import *');
  setStatus('py', { state: 'ready', message: 'Python 3.14 ready', progress: 1 });
  return py;
}
const pagePkgs = new Set<string>();
let warmScheduled = false;
function scheduleWarm() {
  if (warmScheduled || !py) return;
  warmScheduled = true;
  setTimeout(async () => {
    warmScheduled = false;
    const need = [...pagePkgs].filter((p) => !loaded.has(p));
    if (need.length) { try { await ensurePyPackages(need); } catch {} }
  }, 300);
}
export function registerPackagesPy(pkgs: string[]) {
  pkgs.forEach((p) => pagePkgs.add(p));
  if (initPromise && py) scheduleWarm();
}
export function startPy() {
  if (!initPromise) initPromise = init().then((p) => { scheduleWarm(); return p; }).catch((e) => { initPromise = null; setStatus('py', { state: 'error', message: 'Python failed to load: ' + (e?.message || e) }); throw e; });
  return initPromise;
}
export async function ensurePyPackages(pkgs: string[]) {
  await startPy();
  const need = pkgs.filter((p) => !loaded.has(p));
  if (!need.length) return;
  await serial(async () => {
    setStatus('py', { state: 'loading', message: `Loading ${need.join(', ')}…`, progress: 0.6 });
    const builtin = need.filter((p) => !['shap'].includes(p));
    if (builtin.length) await py.loadPackage(builtin, { messageCallback: () => {} });
    for (const p of need.filter((p) => !builtin.includes(p))) {
      await py.loadPackage('micropip'); await py.pyimport('micropip').install(p);
    }
    need.forEach((p) => loaded.add(p));
    setStatus('py', { state: 'ready', message: 'Python 3.14 ready', progress: 1 });
  });
}
export async function runPy(code: string, opts: { packages?: string[] } = {}): Promise<RunOutput> {
  await startPy();
  if (opts.packages?.length) await ensurePyPackages(opts.packages);
  return serial(async () => {
    await ensureLazyData(code);
    setStatus('py', { state: 'busy', message: 'Running Python…' });
    const t0 = performance.now();
    const out: RunOutput = { lines: [], images: [], viz: [], ok: true, ms: 0 };
    py.setStdout({ batched: (s: string) => out.lines.push({ type: 'stdout', text: s + '\n' }) });
    py.setStderr({ batched: (s: string) => out.lines.push({ type: 'stderr', text: s + '\n' }) });
    code = code.replace(/\r\n?/g, '\n');
    try {
      await py.loadPackagesFromImports(code, { messageCallback: () => {} });
      const res = await py.runPythonAsync(code, { globals: py.globals });
      if (res !== undefined && res !== null) {
        const r = py.globals.get('course')._repr(res); out.lines.push({ type: 'stdout', text: r + '\n' });
        res?.destroy?.();
      }
    } catch (e: any) {
      out.ok = false;
      const msg = String(e?.message || e); const lines = msg.trim().split('\n');
      const i = lines.findIndex((l) => l.includes('File "<exec>"'));
      out.lines.push({ type: 'error', text: (i >= 0 ? lines.slice(i).join('\n') : lines.slice(-3).join('\n')).replace(/File "<exec>", /g, '') });
    } finally {
      try {
        const figs = JSON.parse(py.runPython('course._flush_figs()'));
        for (const b64 of figs) { const blob = await (await fetch('data:image/png;base64,' + b64)).blob(); out.images.push(await createImageBitmap(blob)); }
        out.viz = JSON.parse(py.runPython('course._viz_pop()'));
      } catch {}
      out.ms = performance.now() - t0;
      setStatus('py', { state: 'ready', message: 'Python 3.14 ready' });
    }
    return out;
  });
}
export async function parseStepsPy(code: string) {
  await startPy();
  return serial(async () => { py.globals.set('_src', code); return JSON.parse(py.runPython('course._parse_steps(_src)')); });
}
export async function inspectPy() { await startPy(); return serial(async () => JSON.parse(py.runPython('course._inspect(globals())'))); }
export async function resetEnvPy() {
  if (!py) return;
  await serial(async () => py.runPython('for _k in [k for k in list(globals()) if not k.startswith("_") and k not in course._KEEP]: del globals()[_k]\ncourse._hash.clear()'));
}
export async function restartPy() { initPromise = null; py = null; loaded.clear(); fetchedLazy.clear(); queue = Promise.resolve(); setStatus('py', { state: 'idle', message: 'Python restarted', progress: 0 }); return startPy(); }
