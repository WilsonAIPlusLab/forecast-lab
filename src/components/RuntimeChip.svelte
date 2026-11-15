<script lang="ts">
  import { onMount } from 'svelte';
  import { onStatus, type RuntimeState } from '../lib/runtime/status';
  let r: RuntimeState = $state({ state: 'idle', message: '', progress: 0 });
  let p: RuntimeState = $state({ state: 'idle', message: '', progress: 0 });
  let open = $state(false);
  let wrap: HTMLDivElement;
  let chip: HTMLButtonElement;
  onMount(() => {
    const off = onStatus((l, s) => (l === 'r' ? (r = s) : (p = s)));
    // close the panel on Esc (returning focus to the chip) or on a click/focus outside it
    const onKey = (e: KeyboardEvent) => { if (open && e.key === 'Escape') { open = false; chip?.focus(); } };
    const onOut = (e: Event) => { if (open && wrap && !wrap.contains(e.target as Node)) open = false; };
    document.addEventListener('keydown', onKey);
    document.addEventListener('pointerdown', onOut);
    document.addEventListener('focusin', onOut);
    return () => { off?.(); document.removeEventListener('keydown', onKey); document.removeEventListener('pointerdown', onOut); document.removeEventListener('focusin', onOut); };
  });
  const label = (s: RuntimeState, n: string) => (s.state === 'idle' ? `${n} off` : s.state === 'loading' ? `${n} ${Math.round(s.progress * 100)}%` : s.state === 'error' ? `${n} error` : s.state === 'busy' ? `${n} running` : `${n} ready`);
  async function restart(lang: 'r' | 'py') {
    if (lang === 'r') (await import('../lib/runtime/r')).restartR(); else (await import('../lib/runtime/py')).restartPy();
    open = false;
  }
  async function warm() { (await import('../lib/runtime/r')).ensurePackages(['forecast']); open = false; }
</script>
<div class="chip-wrap" bind:this={wrap}>
  <button class="chip" bind:this={chip} type="button" onclick={() => (open = !open)} aria-expanded={open} aria-controls="engine-panel" title="Code engines: status and restart">
    <span class="d {r.state}"></span>{label(r, 'R')}
    {#if p.state !== 'idle'}<span class="sep"></span><span class="d {p.state}"></span>{label(p, 'Py')}{/if}
  </button>
  {#if open}
    <div class="menu" id="engine-panel" role="group" aria-label="Code engines">
      <div class="m-t">Code engines run inside your browser. Nothing to install.</div>
      <div class="m-row"><b>R</b><span>{r.message || 'Not started'}</span></div>
      <div class="m-row"><b>Python</b><span>{p.message || 'Not started'}</span></div>
      <button class="btn btn-sm" onclick={warm}>Warm up R + forecast now</button>
      <div class="m-btns">
        <button class="btn btn-ghost btn-sm" onclick={() => restart('r')}>↻ Restart R</button>
        <button class="btn btn-ghost btn-sm" onclick={() => restart('py')}>↻ Restart Python</button>
      </div>
    </div>
  {/if}
</div>
<style>
  .chip-wrap { position: relative; }
  .chip { all: unset; cursor: pointer; display: flex; align-items: center; gap: .4rem; font: 600 .74rem var(--font-ui); color: var(--text-2); padding: .38rem .7rem; border: 1px solid var(--border); border-radius: 99px; background: var(--surface); }
  .chip:hover { border-color: var(--border-strong); }
  .chip:focus-visible { outline: 2px solid var(--accent-2); outline-offset: 2px; }
  @media (max-width: 400px) { .chip { padding: .38rem .55rem; } }
  .d { width: 7px; height: 7px; border-radius: 50%; background: var(--muted); }
  .d.ready { background: var(--good); box-shadow: 0 0 8px var(--good); }
  .d.loading, .d.busy { background: var(--warm); animation: pl 1s infinite; }
  .d.error { background: var(--danger); }
  @keyframes pl { 50% { opacity: .3; } }
  .sep { width: 1px; height: 12px; background: var(--border-strong); margin: 0 .2rem; }
  .menu { position: absolute; right: 0; top: calc(100% + 8px); width: min(290px, calc(100vw - 2rem)); background: var(--surface); border: 1px solid var(--border-strong); border-radius: 12px; padding: .9rem; box-shadow: var(--shadow); display: grid; gap: .6rem; font-size: .8rem; z-index: 60; }
  .m-t { color: var(--muted); }
  .m-row { display: grid; grid-template-columns: 56px 1fr; gap: .5rem; }
  .m-row span { color: var(--text-2); }
  .m-btns { display: flex; gap: .3rem; }
</style>
