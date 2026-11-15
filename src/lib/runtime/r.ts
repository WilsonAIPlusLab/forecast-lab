// webR (R compiled to WebAssembly) — one shared R session per page.
import { setStatus, BASE } from './status';

const WEBR_URL = 'https://webr.r-wasm.org/v0.6.1/';
export const R_BASE_PACKAGES = ['jsonlite'];

export interface RunOutput {
  lines: { type: 'stdout' | 'stderr' | 'error' | 'echo'; text: string }[];
  images: ImageBitmap[];
  viz: any[];
  ok: boolean;
  ms: number;
}

let webR: any = null;
let initPromise: Promise<any> | null = null;
const installed = new Set<string>();
let queue: Promise<any> = Promise.resolve();

function serial<T>(fn: () => Promise<T>): Promise<T> {
  const p = queue.then(fn, fn);
  queue = p.catch(() => {});
  return p;
}

async function init() {
  setStatus('r', { state: 'loading', message: 'Downloading R (≈15 MB, cached after first visit)…', progress: 0.05 });
  const { WebR } = await import(/* @vite-ignore */ WEBR_URL + 'webr.mjs');
  webR = new WebR({ baseUrl: WEBR_URL, interactive: false });
  await webR.init();
  setStatus('r', { message: 'Loading course data…', progress: 0.35 });
  const manifest = await (await fetch(BASE + 'data/manifest.json')).json();
  try { await webR.FS.mkdir('/home/web_user/data'); } catch {}
  await Promise.all(
    Object.values(manifest).map(async (m: any) => {
      const buf = new Uint8Array(await (await fetch(BASE + 'data/' + m.file)).arrayBuffer());
      await webR.FS.writeFile('/home/web_user/data/' + m.file, buf);
    })
  );
  setStatus('r', { message: 'Installing helpers…', progress: 0.45 });
  await ensurePackagesUnlocked(R_BASE_PACKAGES);
  const helper = await (await fetch(BASE + 'r/course.R')).text();
  await webR.evalRVoid(helper);
  setStatus('r', { state: 'ready', message: 'R 4.6 ready', progress: 1 });
  return webR;
}

// Packages declared by any lab on this page; installed in the background once R is up,
// so later labs don't pay the download cost when the student clicks Run.
const pagePkgs = new Set<string>();
let warmScheduled = false;
function scheduleWarm() {
  if (warmScheduled || !webR) return;
  warmScheduled = true;
  setTimeout(async () => {
    warmScheduled = false;
    const need = [...pagePkgs].filter((p) => !installed.has(p));
    if (need.length) { try { await ensurePackages(need); } catch {} }
  }, 300);
}
export function registerPackagesR(pkgs: string[]) {
  pkgs.forEach((p) => pagePkgs.add(p));
  if (initPromise && webR) scheduleWarm();
}

export function startR(): Promise<any> {
  if (!initPromise) {
    initPromise = init().then((w) => { scheduleWarm(); return w; }).catch((e) => {
      initPromise = null;
      setStatus('r', { state: 'error', message: 'R failed to load: ' + (e?.message || e), progress: 0 });
      throw e;
    });
  }
  return initPromise;
}

async function ensurePackagesUnlocked(pkgs: string[]) {
  const need = pkgs.filter((p) => !installed.has(p));
  for (let i = 0; i < need.length; i++) {
    const p = need[i];
    setStatus('r', { state: 'loading', message: `Installing package ${p} (${i + 1}/${need.length})…`, progress: 0.5 + (0.5 * i) / need.length });
    await webR.installPackages([p], { quiet: true });
    installed.add(p);
  }
}

export async function ensurePackages(pkgs: string[]) {
  await startR();
  return serial(async () => {
    await ensurePackagesUnlocked(pkgs);
    setStatus('r', { state: 'ready', message: 'R 4.6 ready', progress: 1 });
  });
}

/** Evaluate code in the global env, capturing text, base-R graphics and viz specs. */
export async function runR(code: string, opts: { packages?: string[]; width?: number; height?: number } = {}): Promise<RunOutput> {
  await startR();
  if (opts.packages?.length) await ensurePackages(opts.packages);
  return serial(async () => {
    setStatus('r', { state: 'busy', message: 'Running R…' });
    const t0 = performance.now();
    const shelter = await new webR.Shelter();
    const out: RunOutput = { lines: [], images: [], viz: [], ok: true, ms: 0 };
    code = code.replace(/\r\n?/g, '\n');
    try {
      const cap = await shelter.captureR(code, {
        withAutoprint: true,
        captureStreams: true,
        captureConditions: false,
        captureGraphics: { width: opts.width ?? 760, height: opts.height ?? 440 },
      });
      for (const o of cap.output) {
        if (o.type === 'stdout' || o.type === 'stderr') out.lines.push({ type: o.type, text: String(o.data) });
      }
      out.images = cap.images || [];
      if (out.lines.some((l) => l.type === 'stderr' && /^Error/.test(l.text))) out.ok = false;
    } catch (e: any) {
      out.ok = false;
      out.lines.push({ type: 'error', text: cleanError(e?.message || String(e)) });
    } finally {
      try {
        const j = await webR.evalRString('.course_viz_pop()');
        out.viz = JSON.parse(j);
      } catch {}
      shelter.purge();
      out.ms = performance.now() - t0;
      setStatus('r', { state: 'ready', message: 'R 4.6 ready' });
    }
    return out;
  });
}

function cleanError(m: string) {
  return m.replace(/^Error in .*?eval\(.*?\):\s*/s, 'Error: ').replace(/^Error: Error/, 'Error');
}

/** Top-level expression line ranges (1-based, inclusive) — used to step through student-edited code. */
export async function parseStepsR(code: string): Promise<{ start: number; end: number }[]> {
  await startR();
  return serial(async () => {
    const env = await new webR.REnvironment({ code });
    try {
      const j = await webR.evalRString('.course_parse_steps(code)', { env });
      return JSON.parse(j);
    } finally {
      webR.destroy(env);
    }
  });
}

/** Snapshot of user-visible objects: name, class, size, a preview, and whether it changed. */
export async function inspectR(): Promise<any[]> {
  await startR();
  return serial(async () => JSON.parse(await webR.evalRString('.course_inspect()')));
}

export async function resetEnvR() {
  if (!webR) return;
  await serial(() => webR.evalRVoid('rm(list = ls(envir = globalenv(), all.names = FALSE), envir = globalenv()); .course_inspect_reset()'));
}

export async function restartR() {
  try { webR?.close(); } catch {}
  webR = null; initPromise = null; installed.clear(); queue = Promise.resolve();
  setStatus('r', { state: 'idle', message: 'R restarted', progress: 0 });
  return startR();
}
