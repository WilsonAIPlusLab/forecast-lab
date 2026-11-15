<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, fcNaive, fcSNaive, fcDrift, mean } from '../../lib/ts';
  import { C, plotStyle, fmt, watchLayout } from '../../lib/viz/theme';

  // Left: animated diagram of time-series cross-validation (expanding window).
  // Right: the real result of doing it on U.S. retail sales — error grows with the horizon.
  // Sized so that even at h = 12 the evaluated point of the last fold fits: START + FOLDS - 1 + 12 <= N.
  const N = 26;             // dots per row (time points shown)
  const FOLDS = 8;
  const START = 6;          // first training window length
  let h = $state(1);
  let fold = $state(0);
  let playing = $state(true);
  let timer: any;
  let el: HTMLDivElement;
  let curve: { h: number; method: string; mae: number }[] = $state([]);
  const DATA = {
    PAYEMS: { label: 'Payroll jobs (trending)', unit: 'thousand jobs', methods: ['Naive', 'Drift'] },
    RSXFSN: { label: 'Retail sales (seasonal)', unit: '$ millions', methods: ['Seasonal naive', 'Naive', 'Drift'] },
  } as const;
  let sid: keyof typeof DATA = $state('PAYEMS');

  function tickFold() { fold = (fold + 1) % (FOLDS + 3); }
  function play() { clearInterval(timer); timer = setInterval(tickFold, 900); playing = true; }
  function pause() { clearInterval(timer); playing = false; }

  async function compute() {
    const s = await loadSeries(sid, { start: '2010-01-01', end: '2019-12-01' }); // pre-COVID for a clean lesson
    const y = s.data.map((p) => p.value);
    const H = 12, out: typeof curve = [];
    const all: Record<string, (t: number[], h: number) => number[]> = { 'Seasonal naive': (t, k) => fcSNaive(t, k, 12), Naive: fcNaive, Drift: fcDrift };
    for (const name of DATA[sid].methods) {
      const f = all[name];
      const errs: number[][] = Array.from({ length: H }, () => []);
      for (let o = 48; o < y.length - 1; o++) {
        const tr = y.slice(0, o), fc = f(tr, H);
        for (let k = 0; k < H && o + k < y.length; k++) errs[k].push(Math.abs(y[o + k] - fc[k]));
      }
      errs.forEach((e, k) => out.push({ h: k + 1, method: name, mae: mean(e) }));
    }
    curve = out;
  }

  function draw() {
    if (!el || !curve.length) return;
    const pal = C.s;
    const col = (m: string) => (m === 'Seasonal naive' ? pal[0] : m === 'Naive' ? pal[1] : pal[2]);
    el.replaceChildren(Plot.plot({
      width: el.clientWidth, height: 250, marginLeft: 62, marginRight: 100, style: plotStyle(),
      ariaLabel: `Cross-validated MAE by horizon for ${DATA[sid].label.toLowerCase()}, 2010 to 2019`,
      x: { label: 'Forecast horizon (months ahead) →', ticks: 12 }, y: { grid: true, label: `↑ Average error (MAE, ${DATA[sid].unit})`, tickFormat: fmt, zero: true },
      marks: [
        Plot.lineY(curve, { x: 'h', y: 'mae', z: 'method', stroke: (d: any) => col(d.method), strokeWidth: 2.2 }),
        Plot.dot(curve, { x: 'h', y: 'mae', fill: (d: any) => col(d.method), r: (d: any) => (d.h === h ? 6 : 2.5) }),
        Plot.ruleX([h], { stroke: C.borderStrong, strokeDasharray: '3,3' }),
        Plot.text(curve, Plot.selectLast({ x: 'h', y: 'mae', z: 'method', text: 'method', textAnchor: 'start', dx: 8, fill: (d: any) => col(d.method), fontSize: 12, fontWeight: 650 })),
        Plot.tip(curve, Plot.pointer({ x: 'h', y: 'mae', title: (d: any) => `${d.method}, ${d.h} month(s) ahead\nMAE: ${fmt(d.mae)} ${DATA[sid].unit}` })),
      ],
    }));
  }

  $effect(() => { curve; h; draw(); });
  $effect(() => { sid; compute(); });
  onMount(() => { play(); const rq = matchMedia('(prefers-reduced-motion: reduce)'); if (rq.matches) { pause(); fold = FOLDS; } return watchLayout(el, draw); });
  onDestroy(() => clearInterval(timer));

  const rows = $derived(Array.from({ length: Math.min(fold + 1, FOLDS) }, (_, r) => r));
  const cell = (r: number, t: number) => { const end = START + r; if (t < end) return 'train'; if (t === end + h - 1) return 'test'; if (t < end + h - 1) return 'gap'; return 'unused'; };
</script>

<Explorable title="Roll the origin forward: error grows with the horizon" caption="Each row is one <b>fold</b>. The method is trained on the blue points and must forecast the gold point <i>h</i> steps ahead. Then the origin rolls forward one period and we repeat. Averaging the errors across all folds gives a reliable accuracy estimate for every horizon. The chart on the right shows the result of doing exactly this on real 2010–2019 U.S. data.">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Horizon">
      {#each [1, 2, 3, 6, 12] as k}<button class:on={h === k} onclick={() => (h = k)}>h = {k}</button>{/each}
    </div>
    <div class="seg" role="group" aria-label="Data">
      {#each Object.entries(DATA) as [k, d]}<button class:on={sid === k} onclick={() => (sid = k as any)}>{d.label}</button>{/each}
    </div>
    <button class="btn btn-sm" onclick={() => (playing ? pause() : play())}>{playing ? '❚❚ Pause' : '▶ Play'}</button>
  {/snippet}
  <div class="grid2">
    <div class="diag" role="img" aria-label={`Diagram of expanding-window cross-validation: each fold trains on a longer window and is scored ${h} step(s) ahead`}>
      {#each rows as r (r)}
        <div class="row" style="animation-delay:{0}ms">
          <span class="fl">fold {r + 1}</span>
          {#each Array(N) as _, t}<i class={cell(r, t)}></i>{/each}
        </div>
      {/each}
      <div class="axis"><span>time →</span></div>
      <div class="lg"><span><i class="train"></i>training</span><span><i class="test"></i>forecast evaluated</span><span><i class="gap"></i>skipped (h &gt; 1)</span></div>
    </div>
    <div>
      <div class="eyebrow" style="margin-bottom:.3rem">Result on real data: error by horizon</div>
      <div bind:this={el}></div>
    </div>
  </div>
</Explorable>

<style>
  .grid2 { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1.15fr); gap: 1.6rem; align-items: start; }
  @media (max-width: 800px) { .grid2 { grid-template-columns: 1fr; } }
  .diag { display: flex; flex-direction: column; gap: 5px; min-height: 230px; }
  .row { display: flex; align-items: center; gap: 3px; animation: fadeUp .4s both; }
  .fl { font: 600 .75rem var(--font-ui); color: var(--muted); width: 3.6rem; flex-shrink: 0; }
  .row i, .lg i { width: 9px; height: 9px; border-radius: 50%; display: inline-block; flex-shrink: 0; transition: background .3s; }
  i.train { background: var(--c-s1); }
  i.test { background: var(--c-actual); box-shadow: 0 0 8px var(--c-actual); }
  i.gap { background: transparent; border: 1.5px solid var(--border-strong); }
  i.unused { background: var(--surface-3); opacity: .45; }
  .axis { font-size: .75rem; color: var(--muted); padding-left: 3.6rem; margin-top: .2rem; }
  .lg { display: flex; gap: 1rem; flex-wrap: wrap; font-size: .75rem; color: var(--text-2); margin-top: .5rem; }
  .lg span { display: inline-flex; align-items: center; gap: .35rem; }
</style>
