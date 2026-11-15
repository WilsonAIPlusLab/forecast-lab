<script lang="ts">
  // "Predict first, then see": the learner commits to a guess before the answer is revealed.
  import { md } from '../lib/md';
  interface Props { question: string; options: string[]; answer: number; explain: string; kind?: 'predict' | 'check' }
  let { question, options, answer, explain, kind = 'predict' }: Props = $props();
  let pick: number | null = $state(null);
</script>
<div class="pr" class:done={pick !== null}>
  <div class="pr-h"><span class="tag">{kind === 'predict' ? 'Predict first' : 'Check yourself'}</span></div>
  <div class="q">{@html md(question)}</div>
  <div class="opts">
    {#each options as o, i}
      <button class="opt" class:right={pick !== null && i === answer} class:wrong={pick === i && i !== answer} disabled={pick !== null} onclick={() => (pick = i)}>
        <span class="l">{String.fromCharCode(65 + i)}</span><span>{@html md(o)}</span>
      </button>
    {/each}
  </div>
  {#if pick !== null}
    <div class="ex fade-up" aria-live="polite">
      <b>{pick === answer ? 'Yes!' : 'Not quite.'}</b> {@html md(explain)}
      <button class="btn btn-ghost btn-sm" onclick={() => (pick = null)}>Try again</button>
    </div>
  {/if}
</div>
<style>
  .pr { margin: 2rem 0; padding: 1.2rem 1.3rem; border-radius: var(--radius); border: 1px solid var(--border); border-left: 3px solid var(--accent); background: var(--surface); }
  .tag { font-size: .8rem; font-weight: 700; color: var(--accent-text); }
  .done .tag { color: var(--muted); }
  .q { margin: .8rem 0 .9rem; font-weight: 600; color: var(--text); }
  .q :global(p) { margin: 0; }
  .opts { display: grid; gap: .45rem; }
  .opt { all: unset; cursor: pointer; display: flex; gap: .7rem; align-items: flex-start; padding: .65rem .85rem; border: 1px solid var(--border); border-radius: 10px; font-size: .93rem; color: var(--text-2); transition: border-color .15s, background .15s; }
  .opt :global(p) { margin: 0; }
  .opt:hover:not(:disabled) { border-color: var(--accent); background: var(--surface-2); }
  .opt:disabled { cursor: default; }
  .l { font: 700 .75rem var(--font-mono); color: var(--muted); border: 1px solid var(--border-strong); border-radius: 6px; width: 1.4rem; height: 1.4rem; display: grid; place-items: center; flex-shrink: 0; }
  .opt.right { border-color: var(--good); background: rgba(74,222,128,.08); color: var(--text); }
  .opt.right .l { background: var(--good); color: #062; border-color: transparent; }
  .opt.wrong { border-color: var(--danger); background: rgba(248,113,113,.07); }
  .ex { margin-top: .9rem; font-size: .93rem; color: var(--text-2); }
  .ex :global(p) { display: inline; }
</style>
