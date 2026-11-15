<script lang="ts">
  // "Guess the store from its seasonal fingerprint": radial plots of each NSA retail category's average monthly pattern.
  import { onMount } from 'svelte';
  import Explorable from '../Explorable.svelte';
  import { loadSeries } from '../../lib/ts';

  const CATS = [
    { id: 'MRTSSM448USN', name: 'Clothing stores', why: (f: number[]) => `Gift giving. December runs ${f[11] - 100}% above an average month, then January and February collapse.` },
    { id: 'MRTSSM445USN', name: 'Grocery stores', why: (f: number[]) => `People eat every month. The shape is almost a circle: only a modest holiday-meal bump in December (+${f[11] - 100}%).` },
    { id: 'MRTSSM447USN', name: 'Gas stations', why: (f: number[]) => `Summer driving season: May through August all sit near ${Math.round((f[4] + f[5] + f[6] + f[7]) / 4)}. Gas-station sales also swing with the price of gasoline, which tends to be higher in summer.` },
    { id: 'MRTSSM4541USN', name: 'E-commerce', why: (f: number[]) => `Two spikes in a row: November (${f[10]}, the Black Friday and Cyber Monday weekend) and December (${f[11]}).` },
    { id: 'MRTSSM722USN', name: 'Restaurants & bars', why: (f: number[]) => `The flattest fingerprint. Its biggest "season" is February's dip to ${f[1]}, and switch on <b>per day</b> to see how much of that is just a short month.` },
    { id: 'MRTSSM444USN', name: 'Building materials & garden', why: (f: number[]) => `Spring projects: May peaks at ${f[4]}; winter is dead (${f[0]} in January).` },
  ];
  const MON = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
  const MONL = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  let raw: Record<string, { date: Date; value: number }[]> = $state({});
  let perDay = $state(false);
  let order: number[] = $state([0, 1, 2, 3, 4, 5]);
  let round = $state(0);
  let guess: number | null = $state(null);
  let score = $state(0);
  let showAll = $state(false);

  onMount(async () => {
    const all = await Promise.all(CATS.map((c) => loadSeries(c.id, { start: '2015-01-01', end: '2019-12-01' })));
    const r: typeof raw = {};
    all.forEach((s, i) => (r[CATS[i].id] = s.data));
    raw = r;
    // deterministic shuffle so a class sees the same order
    order = [3, 0, 4, 2, 5, 1];
  });

  const days = (d: Date) => new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
  // Index: each month as % of its own year's average month (100 = average), averaged over 2015–2019
  const prints = $derived.by(() => {
    const out: Record<string, number[]> = {};
    for (const c of CATS) {
      const d = raw[c.id]; if (!d) continue;
      const byYear = new Map<number, number[]>();
      for (const p of d) { const v = perDay ? p.value / days(p.date) : p.value; (byYear.get(p.date.getFullYear()) || byYear.set(p.date.getFullYear(), []).get(p.date.getFullYear())!).push(v); }
      const acc = new Array(12).fill(0); let n = 0;
      for (const vals of byYear.values()) { if (vals.length !== 12) continue; const m = vals.reduce((a, b) => a + b, 0) / 12; vals.forEach((v, i) => (acc[i] += (100 * v) / m)); n++; }
      out[c.id] = acc.map((v) => Math.round(v / n));
    }
    return out;
  });
  const ready = $derived(Object.keys(prints).length === CATS.length);
  const cur = $derived(order[round]);
  const done = $derived(round >= CATS.length);

  function pick(i: number) { if (guess !== null) return; guess = i; if (i === cur) score++; }
  function next() { guess = null; round++; if (round >= CATS.length) showAll = true; }
  function restart() { round = 0; score = 0; guess = null; showAll = false; }

  // radial geometry
  const R0 = 18, RMAX = 100, LO = 60, HI = 160;
  const rad = (v: number) => R0 + ((Math.max(LO, Math.min(HI, v)) - LO) / (HI - LO)) * (RMAX - R0);
  const ang = (i: number) => (i / 12) * 2 * Math.PI - Math.PI / 2;
  const pt = (i: number, v: number) => [Math.cos(ang(i)) * rad(v), Math.sin(ang(i)) * rad(v)];
  const shape = (f: number[]) => f.map((v, i) => pt(i, v).map((n) => n.toFixed(1)).join(',')).join(' ');
  const desc = (f: number[]) => { const hi = f.indexOf(Math.max(...f)), lo = f.indexOf(Math.min(...f)); return `Peak ${MONL[hi]} at ${f[hi]}, low ${MONL[lo]} at ${f[lo]} (100 = average month)`; };
</script>

{#snippet radial(f: number[], size: number, labels: boolean, color: string)}
  {@const hi = f.indexOf(Math.max(...f))}
  <svg viewBox="-128 -128 256 256" width={size} height={size} role="img" aria-label={desc(f)}>
    {#each [60, 100, 140] as g}
      <circle r={rad(g)} class="ring" class:avg={g === 100} />
    {/each}
    {#each MON as m, i}
      {@const [x, y] = pt(i, HI)}
      <line x1="0" y1="0" x2={x} y2={y} class="spoke" />
      {#if labels}<text x={Math.cos(ang(i)) * 116} y={Math.sin(ang(i)) * 116} dy="0.35em" text-anchor="middle" class="ml" class:hi={i === hi}>{m}</text>{/if}
    {/each}
    <polygon points={shape(f)} class="fp" style:--c={color} />
    {#each f as v, i}<circle cx={pt(i, v)[0]} cy={pt(i, v)[1]} r={i === hi ? 4.5 : 2.5} class="fpd" style:--c={color} />{/each}
  </svg>
{/snippet}

<Explorable title="Every kind of store has its own seasonal fingerprint" caption="Each shape is one store type's <b>average year</b>, 2015–2019: the distance from the centre shows how big each month is relative to that year's average month (the dashed ring = 100). January is at the top; the year runs clockwise. Data: Census monthly retail trade via FRED, NSA. Switch on <b>per day</b> to remove the effect of months having 28, 30 or 31 days.">
  {#snippet controls()}
    <label class="chk"><input type="checkbox" bind:checked={perDay} /> Per day (divide by days in month)</label>
    <span class="score" aria-live="polite">Score: <b>{score}</b> / {Math.min(round + (guess !== null ? 1 : 0), CATS.length)}</span>
    <button class="btn btn-ghost btn-sm" onclick={() => (showAll = !showAll)}>{showAll ? 'Back to the game' : 'Show all six'}</button>
  {/snippet}
  {#if !ready}
    <div class="loading">Loading six retail series…</div>
  {:else if showAll}
    <div class="grid">
      {#each CATS as c, i}
        <figure class="mini">
          {@render radial(prints[c.id], 210, true, `var(--c-s${(i % 6) + 1})`)}
          <figcaption><b>{c.name}</b><span>{desc(prints[c.id])}</span></figcaption>
        </figure>
      {/each}
    </div>
    {#if done}<p class="end">You identified <b>{score} of {CATS.length}</b>. <button class="btn btn-ghost btn-sm" onclick={restart}>Play again</button></p>{/if}
  {:else}
    <div class="game">
      <div class="mystery">
        <div class="mq">Mystery store {round + 1} of {CATS.length}</div>
        {@render radial(prints[CATS[cur].id], 300, true, guess === null ? 'var(--c-history)' : guess === cur ? 'var(--good)' : 'var(--c-s2)')}
      </div>
      <div class="opts">
        <div class="oq">Which kind of store has this year?</div>
        {#each CATS as c, i}
          <button class="opt" class:right={guess !== null && i === cur} class:wrong={guess === i && i !== cur} disabled={guess !== null} onclick={() => pick(i)}>{c.name}</button>
        {/each}
        {#if guess !== null}
          <div class="reveal" aria-live="polite">
            <p><b>{guess === cur ? 'Yes!' : `It's ${CATS[cur].name.toLowerCase()}.`}</b> {@html CATS[cur].why(prints[CATS[cur].id])}</p>
            <button class="btn btn-sm" onclick={next}>{round + 1 < CATS.length ? 'Next mystery' : 'See all six'}</button>
          </div>
        {/if}
      </div>
    </div>
  {/if}
</Explorable>

<style>
  .loading { padding: 2rem 0; color: var(--muted); }
  .game { display: grid; grid-template-columns: minmax(0, 320px) minmax(0, 1fr); gap: 1.6rem; align-items: start; }
  @media (max-width: 700px) { .game { grid-template-columns: 1fr; justify-items: center; } }
  .mq, .oq { font-size: .84rem; font-weight: 650; color: var(--muted); margin-bottom: .4rem; }
  .opts { display: grid; gap: .45rem; align-content: start; width: 100%; }
  .opt { all: unset; cursor: pointer; padding: .55rem .85rem; border: 1px solid var(--border); border-radius: 10px; font-size: .93rem; color: var(--text-2); transition: border-color .15s, background .15s; }
  .opt:hover:not(:disabled) { border-color: var(--ch, var(--accent)); background: var(--surface-2); }
  .opt:focus-visible { outline: 2px solid var(--accent-2); }
  .opt:disabled { cursor: default; }
  .opt.right { border-color: var(--good); color: var(--text); background: rgba(74, 222, 128, .08); }
  .opt.right::after { content: '  ✓'; color: var(--good); }
  .opt.wrong { border-color: var(--danger); background: rgba(248, 113, 113, .07); }
  .opt.wrong::after { content: '  ✗'; color: var(--danger); }
  .reveal { margin-top: .5rem; font-size: .93rem; color: var(--text-2); }
  .reveal p { margin: 0 0 .6rem; }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 1rem; }
  .mini { margin: 0; display: grid; justify-items: center; gap: .3rem; }
  .mini figcaption { text-align: left; font-size: .8rem; color: var(--muted); display: grid; gap: .1rem; width: 100%; }
  .mini figcaption b { color: var(--text); font-size: .9rem; }
  .end { margin: 1rem 0 0; color: var(--text-2); }
  .score { font-size: .84rem; color: var(--text-2); font-variant-numeric: tabular-nums; }
  .chk { display: inline-flex; gap: .45rem; align-items: center; cursor: pointer; }
  .chk input { accent-color: var(--accent); width: 16px; height: 16px; }
  svg { display: block; max-width: 100%; height: auto; }
  .ring { fill: none; stroke: var(--border); stroke-width: 1; }
  .ring.avg { stroke: var(--border-strong); stroke-dasharray: 4 4; stroke-width: 1.5; }
  .spoke { stroke: var(--border); stroke-width: .75; }
  .ml { font-size: 15px; fill: var(--muted); font-family: var(--font-ui); }
  .ml.hi { fill: var(--text); font-weight: 700; }
  .fp { fill: color-mix(in srgb, var(--c) 22%, transparent); stroke: var(--c); stroke-width: 2.4; stroke-linejoin: round; transition: fill 300ms, stroke 300ms; }
  .fpd { fill: var(--c); stroke: var(--surface); stroke-width: 1; }
  @media (prefers-reduced-motion: reduce) { .fp { transition: none; } }
</style>
