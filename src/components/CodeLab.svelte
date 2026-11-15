<script lang="ts">
  import { onMount, onDestroy, tick } from 'svelte';
  import { createEditor, parseAuthored, type EditorHandle } from '../lib/editor';
  import { onStatus, prefLang, type Lang, type RuntimeState } from '../lib/runtime/status';
  import { renderSpec } from '../lib/viz/render';
  import { md } from '../lib/md';

  interface Props {
    id: string;
    title?: string;
    r?: string;
    py?: string;
    packages?: string[];
    pyPackages?: string[];
    autorun?: boolean;
    caption?: string;
    goal?: string;
    collapsedConsole?: boolean;
    setup?: string;
    pySetup?: string;
    hints?: string[];
    solution?: string;
    solutionPy?: string;
    check?: string;
    checkPy?: string;
    exercise?: boolean;
    onresult?: (viz: any[], lang: Lang) => void;
  }
  let { id, title = 'Code lab', r = '', py = '', packages = [], pyPackages = [], autorun = false, caption = '', goal = '', collapsedConsole = false, setup = '', pySetup = '', hints = [], solution = '', solutionPy = '', check = '', checkPy = '', exercise = false, onresult }: Props = $props();

  const authored = { r: parseAuthored(r), py: parseAuthored(py) };
  const hasR = !!r.trim(), hasPy = !!py.trim();
  let lang: Lang = $state(hasR ? 'r' : 'py');
  let editorEl: HTMLDivElement, outEl: HTMLDivElement = $state()!, rootEl: HTMLElement;
  let ed: EditorHandle;
  let rt: RuntimeState = $state({ state: 'idle', message: '', progress: 0 });
  let running = $state(false);
  let lines: { type: string; text: string }[] = $state([]);
  let ran = $state(false);
  let ms = $state(0);
  let ok = $state(true);
  let showConsole = $state(!collapsedConsole);
  let edited = $state(false);
  let copied = $state(false);
  let lastViz: any[] = [];
  let runToken = 0;
  let hintsShown = $state(0);
  let attempts = $state(0);
  let showedSolution = $state(false);
  const sol = (l: Lang) => (l === 'r' ? solution : solutionPy);
  const chk = (l: Lang) => (l === 'r' ? check : checkPy);
  let lastImgs: ImageBitmap[] = [];

  // step-through
  let stepping = $state(false);
  let steps: { start: number; end: number; note: string }[] = $state([]);
  let stepIdx = $state(-1);
  let vars: any[] = $state([]);
  let stepBusy = $state(false);

  const key = (l: Lang) => `fl-code:${id}:${l}`;
  const saved = (l: Lang) => { try { return localStorage.getItem(key(l)); } catch { return null; } };
  const original = (l: Lang) => authored[l].code;

  async function rt_() {
    return lang === 'r' ? await import('../lib/runtime/r') : await import('../lib/runtime/py');
  }

  async function run() {
    if (running) return;
    exitSteps();
    if (/_{4,}/.test(ed.get())) {
      ran = true; ok = false; lastViz = [{ type: 'check', pass: false, message: 'Fill in every blank (<code>______</code>) before running. Stuck? Press <b>Hint</b>.' }]; lastImgs = []; lines = [];
      await tick(); paint(false); return;
    }
    running = true; ran = true;
    const my = ++runToken;
    const code = withSetup(ed.get());
    const m: any = await rt_();
    const res = lang === 'r' ? await m.runR(code, { packages, width: 760, height: 430 }) : await m.runPy(code, { packages: pyPackages });
    if (my !== runToken) return; // stopped meanwhile
    if (chk(lang).trim()) {
      const c = lang === 'r' ? await m.runR(chk(lang)) : await m.runPy(chk(lang));
      res.viz = [...c.viz.filter((v: any) => v.type === 'check'), ...res.viz];
      if (!c.ok) res.viz.unshift({ type: 'check', pass: false, message: 'Your code ran, but the checker could not find the expected objects. Did you keep the variable names?' });
      attempts++;
    }
    lines = res.lines; ms = res.ms; ok = res.ok;
    lastViz = res.viz; lastImgs = res.images;
    running = false;
    await tick();
    paint(true);
    onresult?.(res.viz, lang);
    window.dispatchEvent(new CustomEvent('lab-run', { detail: { id, lang, ok: res.ok } }));
    markProgress();
  }

  function withSetup(code: string) {
    const s = lang === 'r' ? setup : pySetup;
    return s.trim() ? s + '\n' + code : code;
  }
  async function freshSession(m: any) {
    lang === 'r' ? await m.resetEnvR() : await m.resetEnvPy();
    const s = lang === 'r' ? setup : pySetup;
    if (s.trim()) lang === 'r' ? await m.runR(s, { packages }) : await m.runPy(s, { packages: pyPackages });
    lang === 'r' ? await m.inspectR() : await m.inspectPy();
  }

  function paint(animate = false) {
    if (!outEl) return;
    outEl.innerHTML = '';
    for (const spec of lastViz) {
      const d = document.createElement('div'); d.className = 'lab-viz fade-up'; outEl.append(d); renderSpec(spec, d, { animate });
    }
    for (const img of lastImgs) {
      const c = document.createElement('canvas'); c.width = img.width; c.height = img.height; c.className = 'lab-img fade-up';
      c.getContext('2d')!.drawImage(img, 0, 0); outEl.append(c);
    }
  }

  function markProgress() {
    try { const p = JSON.parse(localStorage.getItem('fl-progress') || '{}'); p[id] = Date.now(); localStorage.setItem('fl-progress', JSON.stringify(p)); } catch {}
  }

  // ── step-through mode ──
  async function startSteps() {
    if (running) return;
    const code = ed.get();
    stepping = true; stepIdx = -1; vars = []; lines = []; lastViz = []; lastImgs = []; paint();
    stepBusy = true;
    const m: any = await rt_();
    if (code === original(lang) && authored[lang].steps.length) steps = authored[lang].steps;
    else {
      try {
        const rng = lang === 'r' ? await m.parseStepsR(code) : await m.parseStepsPy(code);
        steps = rng.map((s: any) => ({ ...s, note: '' }));
      } catch (e: any) { lines = [{ type: 'error', text: 'Cannot step: ' + (e?.message || e) }]; stepBusy = false; stepping = false; return; }
    }
    if (lang === 'r') { if (packages.length) await m.ensurePackages(packages); }
    else if (pyPackages.length) await m.ensurePyPackages(pyPackages);
    // start from a clean session so the inspector shows exactly what each step creates
    await freshSession(m);
    ed.setReadOnly(true);
    stepBusy = false;
    await next();
  }

  async function execStep(i: number) {
    const code = ed.get().split('\n').slice(steps[i].start - 1, steps[i].end).join('\n');
    const m: any = await rt_();
    const res = lang === 'r' ? await m.runR(code, { width: 760, height: 430 }) : await m.runPy(code);
    return res;
  }

  async function next() {
    if (stepBusy || stepIdx >= steps.length - 1) return;
    stepBusy = true; ran = true;
    stepIdx++;
    ed.highlight(steps[stepIdx].start, steps[stepIdx].end, steps[stepIdx].start);
    const res = await execStep(stepIdx);
    lines = res.lines; ok = res.ok; ms = res.ms;
    if (res.viz.length || res.images.length) { lastViz = res.viz; lastImgs = res.images; await tick(); paint(true); }
    const m: any = await rt_();
    vars = lang === 'r' ? await m.inspectR() : await m.inspectPy();
    if (res.viz.length) onresult?.(res.viz, lang);
    stepBusy = false;
    if (stepIdx === steps.length - 1) markProgress();
  }

  async function prev() {
    if (stepBusy || stepIdx <= 0) return;
    // replay from the start up to the previous step (deterministic code)
    const target = stepIdx - 1;
    stepBusy = true;
    const m: any = await rt_();
    await freshSession(m);
    let res: any;
    lastViz = []; lastImgs = [];
    for (let i = 0; i <= target; i++) {
      res = await execStep(i);
      if (res.viz.length || res.images.length) { lastViz = res.viz; lastImgs = res.images; }
      if (i === target - 1) lang === 'r' ? await m.inspectR() : await m.inspectPy();
    }
    stepIdx = target;
    ed.highlight(steps[target].start, steps[target].end, steps[target].start);
    lines = res.lines; ok = res.ok;
    await tick(); paint(false);
    vars = lang === 'r' ? await m.inspectR() : await m.inspectPy();
    stepBusy = false;
  }

  async function finishAll() { while (stepIdx < steps.length - 1) { await next(); } }

  function exitSteps() {
    if (!stepping) return;
    stepping = false; stepIdx = -1; ed.clear(); ed.setReadOnly(false);
  }

  async function stop() {
    runToken++;
    const m: any = await rt_();
    lang === 'r' ? m.restartR() : m.restartPy();
    running = false; stepBusy = false;
    lines = [{ type: 'error', text: `Stopped. ${lang === 'r' ? 'R' : 'Python'} was restarted, so earlier results are cleared. Edit and run again.` }]; ok = false;
  }

  function showHint() { hintsShown = Math.min(hints.length, hintsShown + 1); }
  function showSolution() {
    if (!sol(lang)) return;
    exitSteps(); ed.set(sol(lang).replace(/^\n+|\s+$/g, '')); showedSolution = true;
  }

  function reset() {
    exitSteps();
    ed.set(original(lang));
    try { localStorage.removeItem(key(lang)); } catch {}
    edited = false;
  }

  async function copy() {
    await navigator.clipboard.writeText(ed.get());
    copied = true; setTimeout(() => (copied = false), 1400);
  }

  function switchLang(l: Lang) {
    if (l === lang || (l === 'r' && !hasR) || (l === 'py' && !hasPy)) return;
    exitSteps();
    lang = l; ed.setLang(l); ed.set(saved(l) ?? original(l)); edited = ed.get() !== original(l);
    lines = []; lastViz = []; lastImgs = []; ran = false; paint();
  }

  let mounted = $state(false);
  let off: any, ro: ResizeObserver;
  onMount(() => { init(); return () => { window.removeEventListener('lang-change', onLang); window.removeEventListener('theme-change', onTheme); }; });
  const onLang = (e: any) => switchLang(e.detail);
  const onTheme = () => paint(false);
  async function init() {
    mounted = true;
    // let the runtimes pre-install this lab's packages as soon as they start (no engine start here)
    if (packages.length) import('../lib/runtime/r').then((m) => m.registerPackagesR(packages));
    if (pyPackages.length) import('../lib/runtime/py').then((m) => m.registerPackagesPy(pyPackages));
    await tick();
    const pref = prefLang.get();
    if (pref === 'py' && hasPy) lang = 'py';
    ed = createEditor(editorEl, {
      doc: saved(lang) ?? original(lang), lang,
      onRun: run,
      onChange: (s) => { edited = s !== original(lang); try { edited ? localStorage.setItem(key(lang), s) : localStorage.removeItem(key(lang)); } catch {} },
    });
    edited = ed.get() !== original(lang);
    off = onStatus((l, s) => { if (l === lang) rt = s; });
    window.addEventListener('lang-change', onLang);
    window.addEventListener('theme-change', onTheme);
    let w = 0;
    ro = new ResizeObserver(() => { const nw = outEl?.clientWidth || 0; if (Math.abs(nw - w) > 40 && lastViz.length) { w = nw; paint(false); } else w = nw; });
    ro.observe(rootEl);
    if (autorun) {
      const io = new IntersectionObserver((es) => { if (es[0].isIntersecting) { io.disconnect(); run(); } }, { rootMargin: '200px' });
      io.observe(rootEl);
    }
  }
  onDestroy(() => { off?.(); ro?.disconnect(); ed?.destroy(); });

  const statusLabel = $derived(rt.state === 'loading' ? rt.message : rt.state === 'busy' ? 'Running…' : rt.state === 'ready' ? (lang === 'r' ? 'R ready' : 'Python ready') : rt.state === 'error' ? rt.message : lang === 'r' ? 'R starts on first run' : 'Python starts on first run');

  function spark(v: number[]) {
    const vals = v.filter((x) => x != null && isFinite(x)); if (vals.length < 2) return '';
    const mn = Math.min(...vals), mx = Math.max(...vals), W = 120, H = 26;
    const pts = v.map((x, i) => (x == null ? null : `${(i / (v.length - 1)) * W},${H - 2 - ((x - mn) / (mx - mn || 1)) * (H - 4)}`)).filter(Boolean).join(' ');
    return `<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}"><polyline points="${pts}" fill="none" stroke="var(--accent-2)" stroke-width="1.4"/></svg>`;
  }
</script>

<section class="lab" bind:this={rootEl} aria-label={title}>
  <header class="lab-head">
    <div class="lab-title">
      <span class="lab-dot" class:live={rt.state === 'ready' || rt.state === 'busy'} class:loading={rt.state === 'loading'}></span>
      <span>{title}</span>
      {#if edited}<span class="pill">edited</span>{/if}
    </div>
    <div class="lab-tabs" role="tablist" aria-label="Language">
      {#if hasR}<button role="tab" aria-selected={lang === 'r'} class:on={lang === 'r'} onclick={() => prefLang.set('r')}>R</button>{/if}
      {#if hasPy}<button role="tab" aria-selected={lang === 'py'} class:on={lang === 'py'} onclick={() => prefLang.set('py')}>Python</button>{/if}
    </div>
  </header>
  {#if goal}<div class="lab-goal"><span>{exercise ? 'Your task' : 'Goal'}</span>{@html md(goal)}</div>{/if}
  {#if hintsShown > 0}
    <div class="lab-hints">{#each hints.slice(0, hintsShown) as h, i}<div class="hint fade-up"><span>Hint {i + 1}</span>{@html md(h)}</div>{/each}</div>
  {/if}

  <div class="lab-body" class:stepping>
    <div class="lab-code">
      <div class="editor" bind:this={editorEl}>{#if !mounted}<pre class="ssr-code">{original(lang)}</pre>{/if}</div>
      <div class="lab-bar">
        {#if running}
          <button class="btn btn-sm stopbtn" onclick={stop} title="Stop (restarts the engine)"><span class="spin"></span> Stop</button>
        {:else}
          <button class="btn btn-primary btn-sm" onclick={run} disabled={stepBusy} title="Run all (Ctrl+Enter)">▶ {exercise ? 'Run & check' : 'Run'}</button>
        {/if}
        {#if !stepping}
          <button class="btn btn-sm" onclick={startSteps} disabled={running} title="Execute one step at a time with explanations">⏯ Step through</button>
        {:else}
          <button class="btn btn-sm" onclick={exitSteps}>✕ Exit steps</button>
        {/if}
        <button class="btn btn-ghost btn-sm" onclick={reset} disabled={!edited} title="Restore original code">↺ Reset</button>
        <button class="btn btn-ghost btn-sm" onclick={copy}>{copied ? '✓ Copied' : '⧉ Copy'}</button>
        {#if hints.length}<button class="btn btn-ghost btn-sm" onclick={showHint} disabled={hintsShown >= hints.length}>Hint {hintsShown < hints.length ? `(${hintsShown + 1}/${hints.length})` : ''}</button>{/if}
        {#if sol(lang)}<button class="btn btn-ghost btn-sm" onclick={showSolution} disabled={exercise && attempts === 0 && hintsShown === 0} title={exercise && attempts === 0 ? 'Try running your own attempt first' : 'Load the model solution'}>Show solution</button>{/if}
        <span class="lab-status" class:err={rt.state === 'error'}>
          {#if rt.state === 'loading'}<span class="prog"><i style="width:{Math.round(rt.progress * 100)}%"></i></span>{/if}
          {statusLabel}{#if ran && !running && rt.state === 'ready'} · {ms < 1000 ? Math.round(ms) + ' ms' : (ms / 1000).toFixed(1) + ' s'}{/if}
        </span>
      </div>
    </div>

    {#if stepping}
      <aside class="stepper" aria-live="polite">
        <div class="step-top">
          <span class="eyebrow">Step {Math.max(stepIdx + 1, 0)} of {steps.length}</span>
          <div class="dots">{#each steps as _, i}<i class:done={i < stepIdx} class:cur={i === stepIdx}></i>{/each}</div>
        </div>
        <div class="step-note">
          {#if stepBusy && stepIdx < 0}<p class="muted">Preparing…</p>
          {:else if stepIdx >= 0}
            {#if steps[stepIdx].note}{@html md(steps[stepIdx].note)}{:else}<p class="muted">Lines {steps[stepIdx].start}–{steps[stepIdx].end} ran. Look at what changed below.</p>{/if}
          {/if}
        </div>
        <div class="step-ctrl">
          <button class="btn btn-sm" onclick={prev} disabled={stepBusy || stepIdx <= 0}>← Back</button>
          <button class="btn btn-primary btn-sm" onclick={next} disabled={stepBusy || stepIdx >= steps.length - 1}>{stepBusy ? 'Running…' : 'Next step →'}</button>
          <button class="btn btn-ghost btn-sm" onclick={finishAll} disabled={stepBusy || stepIdx >= steps.length - 1}>Run rest</button>
        </div>
        {#if stepIdx >= 0 && lines.length}
          <div class="step-out" class:err={!ok}>
            <div class="eyebrow">Output of this step</div>
            <pre>{#each lines as l}<span class={l.type}>{l.text}{l.text.endsWith('\n') ? '' : '\n'}</span>{/each}</pre>
          </div>
        {/if}
        {#if vars.length}
          <div class="vars">
            <div class="eyebrow">Objects in memory</div>
            {#each vars.filter((v) => v.status !== 'same').concat(vars.filter((v) => v.status === 'same')) as v (v.name)}
              <div class="var" class:fresh={v.status !== 'same'}>
                <div class="var-h"><code>{v.name}</code>{#if v.status !== 'same'}<span class="badge {v.status}">{v.status}</span>{/if}<span class="var-c">{v.class}</span></div>
                <div class="var-s">{v.summary}</div>
                {#if v.spark && v.status !== 'same'}{@html spark(v.spark)}{/if}
                {#if v.table && v.status !== 'same'}
                  <div class="mini"><table><thead><tr>{#each v.table.columns as c}<th>{c}</th>{/each}</tr></thead><tbody>{#each v.table.rows as row}<tr>{#each row as c}<td>{c ?? 'NA'}</td>{/each}</tr>{/each}</tbody></table></div>
                {/if}
              </div>
            {/each}
          </div>
        {/if}
      </aside>
    {/if}
  </div>

  <div class="lab-out" class:empty={!ran}>
    <div class="viz-out" bind:this={outEl}></div>
    {#if !ran}
      <div class="placeholder"><span>▶</span> Press <b>Run</b> (or <kbd>Ctrl</kbd>+<kbd>Enter</kbd>) to execute — or <b>Step through</b> to go line by line.</div>
    {/if}
    {#if lines.length}
      <div class="console" class:err={!ok}>
        <button class="console-t" onclick={() => (showConsole = !showConsole)} aria-expanded={showConsole}>{showConsole ? '▾' : '▸'} Console output <span class="muted">({lines.length})</span></button>
        {#if showConsole}<pre>{#each lines as l}<span class={l.type}>{l.text}{l.text.endsWith('\n') ? '' : '\n'}</span>{/each}</pre>{/if}
      </div>
    {/if}
  </div>
  {#if caption}<div class="lab-cap">{@html md(caption)}</div>{/if}
</section>

<style>
  .lab { margin: 2.2rem 0; border: 1px solid var(--border); border-radius: var(--radius); background: linear-gradient(180deg, var(--surface) 0%, var(--bg-2) 100%); box-shadow: var(--shadow); overflow: hidden; position: relative; }
  .lab-head { display: flex; align-items: center; justify-content: space-between; padding: .7rem 1rem; border-bottom: 1px solid var(--border); gap: 1rem; }
  .lab-title { display: flex; align-items: center; gap: .6rem; font-weight: 650; font-size: .92rem; }
  .lab-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--muted); }
  .lab-dot.live { background: var(--good); box-shadow: 0 0 10px var(--good); }
  .lab-dot.loading { background: var(--warm); animation: pulse 1s infinite; }
  @keyframes pulse { 50% { opacity: .3; } }
  .pill { font-size: .68rem; padding: .1rem .5rem; border-radius: 99px; background: rgba(245,158,11,.15); color: var(--warm); font-weight: 600; }
  .lab-tabs { display: flex; background: var(--bg); border: 1px solid var(--border); border-radius: 9px; padding: 2px; }
  .lab-tabs button { all: unset; cursor: pointer; font: 600 .76rem var(--font-ui); padding: .32rem .8rem; border-radius: 7px; color: var(--muted); }
  .lab-tabs button.on { background: var(--surface-3); color: var(--text); }
  .lab-goal { display: flex; gap: .7rem; align-items: baseline; padding: .6rem 1rem; font-size: .9rem; background: rgba(124,92,255,.07); border-bottom: 1px solid var(--border); color: var(--text-2); }
  .lab-goal span { font-size: .8rem; font-weight: 700; color: var(--accent-text); }
  .lab-goal :global(p) { margin: 0; }
  .lab-hints { border-bottom: 1px solid var(--border); background: rgba(52,211,153,.06); padding: .5rem 1rem; display: grid; gap: .35rem; }
  .hint { display: flex; gap: .7rem; align-items: baseline; font-size: .88rem; color: var(--text-2); }
  .hint span { font-size: .78rem; font-weight: 700; color: var(--accent-3); white-space: nowrap; }
  .hint :global(p) { margin: 0; }
  .stopbtn { border-color: rgba(248,113,113,.5); color: var(--danger); }
  .stopbtn .spin { border-color: rgba(248,113,113,.3); border-top-color: var(--danger); }
  .lab-body { display: grid; grid-template-columns: 1fr; }
  .lab-body.stepping { grid-template-columns: minmax(0, 1.25fr) minmax(280px, 1fr); }
  @media (max-width: 860px) { .lab-body.stepping { grid-template-columns: 1fr; } }
  .lab-code { min-width: 0; display: flex; flex-direction: column; }
  .editor { max-height: 560px; overflow: auto; background: var(--bg); }
  .ssr-code { margin: 0; padding: 14px 16px 14px 52px; font: 13.6px/1.65 var(--font-mono); color: var(--text-2); white-space: pre-wrap; font-variant-ligatures: none; }
  .lab-bar { display: flex; align-items: center; gap: .45rem; padding: .55rem .8rem; border-top: 1px solid var(--border); flex-wrap: wrap; }
  .lab-status { margin-left: auto; font-size: .75rem; color: var(--muted); display: flex; align-items: center; gap: .5rem; }
  .lab-status.err { color: var(--danger); }
  .prog { width: 70px; height: 4px; background: var(--surface-3); border-radius: 4px; overflow: hidden; display: inline-block; }
  .prog i { display: block; height: 100%; background: var(--grad); transition: width .4s; }
  .spin { width: 11px; height: 11px; border: 2px solid rgba(255,255,255,.35); border-top-color: #fff; border-radius: 50%; animation: sp .7s linear infinite; display: inline-block; }
  @keyframes sp { to { transform: rotate(360deg); } }

  .stepper { border-left: 1px solid var(--border); padding: 1rem 1.1rem; background: var(--surface); display: flex; flex-direction: column; gap: .8rem; max-height: 640px; overflow: auto; }
  @media (max-width: 860px) { .stepper { border-left: 0; border-top: 1px solid var(--border); } }
  .step-top { display: flex; justify-content: space-between; align-items: center; gap: .6rem; }
  .dots { display: flex; gap: 4px; flex-wrap: wrap; }
  .dots i { width: 14px; height: 4px; border-radius: 3px; background: var(--surface-3); }
  .dots i.done { background: var(--accent); opacity: .6; }
  .dots i.cur { background: var(--accent-2); }
  .step-note { font-size: .93rem; line-height: 1.6; color: var(--text-2); min-height: 3.5em; }
  .step-note :global(p) { margin: 0 0 .6em; }
  .step-note :global(code) { font-size: .82em; }
  .step-note :global(ul) { margin: .1em 0 .6em; padding-left: 1.15rem; }
  .step-note :global(li) { margin: .15em 0; }
  .step-ctrl { display: flex; gap: .4rem; flex-wrap: wrap; }
  .step-out pre { margin: .35rem 0 0; padding: .55rem .7rem; background: var(--bg); border: 1px solid var(--border); border-radius: 8px; font: .72rem/1.5 var(--font-mono); max-height: 220px; overflow: auto; color: var(--text-2); }
  .step-out.err pre { border-color: rgba(248,113,113,.5); }
  .step-out :global(.error) { color: var(--danger); white-space: pre-wrap; }
  .step-out :global(.stderr) { color: var(--warm); }
  .vars { border-top: 1px dashed var(--border); padding-top: .7rem; display: flex; flex-direction: column; gap: .45rem; }
  .var { padding: .5rem .6rem; border-radius: 8px; border: 1px solid transparent; font-size: .8rem; }
  .var.fresh { border-color: rgba(34,211,238,.35); background: rgba(34,211,238,.06); animation: fadeUp .4s both; }
  .var-h { display: flex; align-items: center; gap: .45rem; }
  .var-c { margin-left: auto; color: var(--muted); font-size: .72rem; }
  .var-s { color: var(--muted); font-family: var(--font-mono); font-size: .72rem; margin-top: .2rem; word-break: break-word; }
  .badge { font-size: .7rem; font-weight: 700; padding: .05rem .4rem; border-radius: 4px; }
  .badge.new { background: rgba(74,222,128,.15); color: var(--good); }
  .badge.changed { background: rgba(245,158,11,.15); color: var(--warm); }
  .mini { overflow-x: auto; margin-top: .35rem; }
  .mini table { font-size: .68rem; font-family: var(--font-mono); }
  .mini th, .mini td { padding: .15rem .4rem; white-space: nowrap; }

  .lab-out { border-top: 1px solid var(--border); padding: 1.1rem 1.2rem 1.2rem; min-height: 90px; }
  .lab-out.empty { padding: 0; min-height: 0; }
  .placeholder { padding: 1.1rem 1.2rem; color: var(--muted); font-size: .87rem; display: flex; gap: .5rem; align-items: center; }
  .placeholder span { color: var(--accent-text); }
  .viz-out :global(.lab-viz) { margin-bottom: 1.4rem; }
  .viz-out :global(.lab-viz:last-child) { margin-bottom: .6rem; }
  .viz-out :global(.lab-img) { max-width: 100%; height: auto; border-radius: 8px; background: #fff; margin-bottom: 1rem; }
  .console { border: 1px solid var(--border); border-radius: 9px; background: var(--bg); overflow: hidden; }
  .console.err { border-color: rgba(248,113,113,.45); }
  .console-t { all: unset; cursor: pointer; display: block; width: 100%; box-sizing: border-box; padding: .45rem .8rem; font-size: .76rem; font-weight: 600; color: var(--text-2); }
  .console pre { margin: 0; padding: .3rem .9rem .8rem; font: .78rem/1.55 var(--font-mono); overflow: auto; max-height: 340px; color: var(--text-2); white-space: pre; }
  .console :global(.stderr) { color: var(--warm); }
  .console :global(.error) { color: var(--danger); white-space: pre-wrap; }
  .lab-cap { padding: .7rem 1.2rem; font-size: .86rem; color: var(--muted); border-top: 1px solid var(--border); background: var(--bg-2); }
  .lab-cap :global(p) { margin: 0; }
</style>
