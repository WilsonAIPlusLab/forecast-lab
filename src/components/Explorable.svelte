<script lang="ts">
  // Consistent frame for every interactive figure: label, title, controls, figure body, caption.
  import type { Snippet } from 'svelte';
  interface Props { title: string; kicker?: string; caption?: string; controls?: Snippet; children: Snippet; aside?: Snippet; wide?: boolean }
  let { title, kicker = 'Interactive', caption = '', controls, children, aside, wide = false }: Props = $props();
</script>
<figure class="exp" class:wide>
  <figcaption class="exp-h">
    <span class="exp-k"><span class="pulse"></span>{kicker}</span>
    <span class="exp-t">{title}</span>
  </figcaption>
  {#if controls}<div class="exp-ctrl">{@render controls()}</div>{/if}
  <div class="exp-body" class:has-aside={!!aside}>
    <div class="exp-main">{@render children()}</div>
    {#if aside}<div class="exp-aside">{@render aside()}</div>{/if}
  </div>
  {#if caption}<div class="exp-cap">{@html caption}</div>{/if}
</figure>
<style>
  .exp { margin: 2.4rem 0; border: 1px solid var(--border); border-radius: var(--radius); background: var(--surface); box-shadow: var(--shadow); overflow: hidden; }
  .exp-h { display: flex; flex-direction: column; gap: .2rem; padding: 1rem 1.25rem .4rem; }
  .exp-k { display: inline-flex; align-items: center; gap: .45rem; font-size: .8rem; font-weight: 650; color: var(--accent-2); }
  .pulse { width: 7px; height: 7px; border-radius: 50%; background: var(--accent-2); box-shadow: 0 0 0 0 rgba(34,211,238,.6); animation: pu 2.2s infinite; }
  @keyframes pu { 70% { box-shadow: 0 0 0 7px rgba(34,211,238,0); } 100% { box-shadow: 0 0 0 0 rgba(34,211,238,0); } }
  .exp-t { font-weight: 650; font-size: 1.08rem; color: var(--text); letter-spacing: -.01em; }
  .exp-ctrl { display: flex; flex-wrap: wrap; gap: .7rem 1.4rem; align-items: center; padding: .5rem 1.25rem .8rem; border-bottom: 1px solid var(--border); font-size: .84rem; color: var(--text-2); }
  .exp-body { padding: 1rem 1.25rem 1.1rem; display: grid; gap: 1.2rem; }
  .exp-body.has-aside { grid-template-columns: minmax(0, 1fr) 270px; }
  @media (max-width: 860px) { .exp-body.has-aside { grid-template-columns: 1fr; } }
  .exp-main { min-width: 0; }
  .exp-cap { padding: .75rem 1.25rem; font-size: .86rem; color: var(--muted); border-top: 1px solid var(--border); background: var(--bg-2); line-height: 1.55; }
  /* shared control styles for explorables */
  .exp :global(.seg) { display: inline-flex; background: var(--bg); border: 1px solid var(--border); border-radius: 9px; padding: 2px; flex-wrap: wrap; }
  .exp :global(.seg button) { all: unset; cursor: pointer; font: 600 .78rem var(--font-ui); padding: .34rem .75rem; border-radius: 7px; color: var(--muted); }
  .exp :global(.seg button.on) { background: var(--surface-3); color: var(--text); box-shadow: 0 1px 0 rgba(255,255,255,.05) inset; }
  .exp :global(.seg button:focus-visible) { outline: 2px solid var(--accent-2); }
  .exp :global(label.sl) { display: inline-flex; align-items: center; gap: .6rem; }
  .exp :global(label.sl b) { font: 600 .8rem var(--font-mono); color: var(--text); min-width: 4.5ch; }
  .exp :global(input[type='range']) { accent-color: var(--accent); width: 150px; }
  .exp :global(.stat) { display: flex; flex-direction: column; gap: .1rem; }
  .exp :global(.stat-v) { font: 650 1.5rem/1.1 var(--font-ui); font-variant-numeric: tabular-nums; color: var(--text); }
  .exp :global(.stat-l) { font-size: .74rem; color: var(--muted); }
</style>
