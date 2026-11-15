<script lang="ts">
  // Ordering switcher: the same VAR, six Cholesky orderings. Move the Fed in the causal chain
  // and watch the "effect of a rate hike" morph. Precomputed in R (build_data.R, vars::irf, 300 bootstrap runs).
  import { onMount, untrack } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { D, BASE, META, col, sgn, reduced, type VarKey } from './varlib';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';

  const RESP: VarKey[] = ['infl', 'unemp', 'ffr'];
  const H = D.meta.h;
  const POS = { first: ['ffr,infl,unemp', 'ffr,unemp,infl'], middle: ['infl,ffr,unemp', 'unemp,ffr,infl'], last: ['infl,unemp,ffr', 'unemp,infl,ffr'] } as const;
  type P = keyof typeof POS;
  let pos: P = $state('last');
  let swap = $state(false);
  const ord = $derived(POS[pos][swap ? 1 : 0]);
  const chain = $derived(ord.split(',') as VarKey[]);

  // global y-domains per response so axes never jump between orderings
  const dom = Object.fromEntries(RESP.map((r) => { const v = Object.values(D.irf).flatMap((o) => [...o.ffr[r].lo, ...o.ffr[r].hi, 0]); return [r, [Math.min(...v), Math.max(...v)]]; })) as Record<VarKey, [number, number]>;

  // animated state: current displayed curves, tweened toward the target ordering
  type Cur = Record<VarKey, { pt: number[]; lo: number[]; hi: number[] }>;
  const snap = (o: string): Cur => Object.fromEntries(RESP.map((r) => [r, { pt: [...D.irf[o].ffr[r].pt], lo: [...D.irf[o].ffr[r].lo], hi: [...D.irf[o].ffr[r].hi] }])) as Cur;
  let cur: Cur = $state(snap(BASE));
  let raf = 0;
  function morph(to: string) {
    cancelAnimationFrame(raf);
    const from = $state.snapshot(cur) as Cur, target = snap(to);
    if (reduced()) { cur = target; return; }
    const t0 = performance.now(), dur = 420;
    const ease = (x: number) => 1 - Math.pow(1 - x, 3);
    const step = (now: number) => {
      const k = ease(Math.min(1, (now - t0) / dur));
      cur = Object.fromEntries(RESP.map((r) => [r, Object.fromEntries((['pt', 'lo', 'hi'] as const).map((f) => [f, from[r][f].map((v, i) => v + (target[r][f][i] - v) * k)]))])) as Cur;
      if (k < 1) raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
  }
  let first = true;
  $effect(() => { const o = ord; if (first) { first = false; return; } untrack(() => morph(o)); });

  let el: HTMLDivElement;
  function draw() {
    if (!el) return;
    const W = el.clientWidth, cols = W < 600 ? 1 : 3, w = (W - 14 * (cols - 1)) / cols;
    const ghost = D.irf[BASE].ffr;
    const nodes = RESP.map((r) => {
      const rows = cur[r].pt.map((v, h) => ({ h, v, lo: cur[r].lo[h], hi: cur[r].hi[h], g: ghost[r].pt[h] }));
      const box = document.createElement('div');
      box.innerHTML = `<div class="pt" style="color:${col(r)}">${META[r].label}</div>`;
      box.append(Plot.plot({
        width: w, height: 220, marginLeft: 42, marginRight: 8, marginTop: 8, marginBottom: 34, style: plotStyle(),
        x: { domain: [0, H], ticks: [0, 4, 8, 12, 16, 20], label: 'quarters after the hike', labelAnchor: 'right' },
        y: { domain: dom[r], grid: true, nice: true, label: 'pp', tickFormat: (d: number) => (d > 0 ? '+' : '') + d },
        ariaLabel: `Response of ${META[r].label} to a funds-rate shock under ordering ${ord}`,
        marks: [
          Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
          Plot.areaY(rows, { x: 'h', y1: 'lo', y2: 'hi', fill: col(r), fillOpacity: 0.16, curve: 'monotone-x' }),
          ord !== BASE && ord !== 'unemp,infl,ffr' ? Plot.lineY(rows, { x: 'h', y: 'g', stroke: C.muted, strokeOpacity: 0.55, strokeWidth: 1.4, strokeDasharray: '4,3', curve: 'monotone-x' }) : null,
          Plot.lineY(rows, { x: 'h', y: 'v', stroke: col(r), strokeWidth: 2.6, curve: 'monotone-x' }),
          Plot.dot(rows.filter((d) => d.h === 0), { x: 'h', y: 'v', fill: col(r), r: 4 }),
          Plot.tip(rows, Plot.pointerX({ x: 'h', y: 'v', title: (d: any) => `${META[r].label}, ${d.h} quarter(s) after the hike\n${sgn(d.v, 3)} pp (90% band ${sgn(d.lo)} to ${sgn(d.hi)})\nbaseline (Fed last): ${sgn(d.g, 3)} pp` })),
        ],
      }));
      return box;
    });
    const grid = document.createElement('div'); grid.className = 'g3'; grid.style.gridTemplateColumns = `repeat(${cols}, minmax(0,1fr))`;
    grid.append(...nodes);
    el.replaceChildren(grid);
  }
  $effect(() => { cur; draw(); });
  onMount(() => { const off = watchLayout(el, draw); return () => { off(); cancelAnimationFrame(raf); }; });

  // impact matrix: same-quarter response of each variable (rows) to each shock (columns), in this ordering
  const impact = $derived(chain.map((r) => chain.map((s) => D.irf[ord][s][r].pt[0])));
  const corr = D.meta.resid_cor; // order infl, unemp, ffr
  const sameAsBase = $derived(D.irf[ord].ffr.infl.pt.every((v, i) => Math.abs(v - D.irf[BASE].ffr.infl.pt[i]) < 1e-9));
  const VERDICT: Record<P, string> = {
    last: 'The Fed sees this quarter’s inflation and unemployment before it sets the rate; prices and hiring react to the rate only from next quarter on. A hike then raises unemployment slowly, and inflation shows the short-lived price puzzle.',
    middle: 'The Fed now reacts within the quarter to one variable but not the other. The responses land between the two extremes, and which variable the Fed is allowed to see changes the answer.',
    first: 'Now the Fed moves first and both other variables may react within the same quarter. Their same-quarter co-movement with rates gets credited to the Fed, so a “hike” seems to raise inflation sharply and cut unemployment for a year. Few economists find that story believable.',
  };
</script>

<Explorable title="Move the Fed in the causal chain and the “effect of a hike” changes"
  caption={`Each panel shows the response to a one-standard-deviation surprise in the funds rate, with a 90% bootstrap band (300 replications). The grey dashed line is the baseline ordering (Fed last), for comparison. The data and the VAR never change, only the assumed order in which variables can react within a quarter. Try <b>Swap the other two</b> with the Fed first or last: nothing moves. VAR(4), 1960Q1–2000Q4.`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Position of the Fed in the Cholesky ordering">
      {#each [['first', 'Fed first'], ['middle', 'Fed in the middle'], ['last', 'Fed last']] as [k, l]}<button class:on={pos === k} onclick={() => (pos = k as P)}>{l}</button>{/each}
    </div>
    <label class="chk"><input type="checkbox" bind:checked={swap} /> Swap the other two</label>
  {/snippet}
  {#snippet aside()}
    <div class="side">
      <div class="lbl">Ordering (who can react to whom within a quarter)</div>
      <div class="chain" aria-label={`Ordering: ${chain.map((k) => META[k].label).join(', then ')}`}>
        {#each chain as k, i}<span class="ck" style:border-color={col(k)} style:color={col(k)}>{META[k].short}</span>{#if i < 2}<span class="ar">→</span>{/if}{/each}
      </div>
      <div class="lbl">Same-quarter impact (pp), from the Cholesky factor</div>
      <table class="imp">
        <thead><tr><th></th>{#each chain as s}<th style:color={col(s)}>{META[s].short} shock</th>{/each}</tr></thead>
        <tbody>
          {#each chain as r, i}
            <tr><th style:color={col(r)}>{META[r].short}</th>
              {#each chain as s, j}<td class:zero={j > i}>{j > i ? '0' : impact[i][j].toFixed(2)}</td>{/each}</tr>
          {/each}
        </tbody>
      </table>
      <p class="note">The shaded zeros are <b>assumed</b>, not estimated. That triangle of zeros is the identification.</p>
      <p class="verdict" aria-live="polite">{VERDICT[pos]}{#if sameAsBase && pos === 'last' && swap}{' '}<b>Identical to the baseline</b>: swapping the variables above the Fed leaves the policy shock unchanged.{/if}{#if pos === 'first' && swap}{' '}<b>Same as before the swap</b>: only the Fed’s position matters for its own shock.{/if}</p>
      <p class="note">Residual correlations: inflation–funds rate {corr[0][2].toFixed(2)}, unemployment–funds rate {corr[1][2].toFixed(2)}. With zero correlations, every ordering would give the same answer.</p>
    </div>
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 230px; }
  .chart :global(.g3) { display: grid; gap: 14px; }
  .chart :global(.pt) { font: 650 .86rem var(--font-ui); margin-bottom: 2px; }
  .chk { display: inline-flex; gap: .45rem; align-items: center; font-size: .84rem; cursor: pointer; }
  .chk input { accent-color: var(--ch, var(--accent)); width: 16px; height: 16px; }
  .side { font-size: .82rem; color: var(--text-2); }
  .lbl { font-size: .75rem; color: var(--muted); font-weight: 650; margin: .2rem 0 .35rem; }
  .chain { display: flex; align-items: center; gap: .3rem; flex-wrap: wrap; margin-bottom: .8rem; }
  .ck { border: 1.5px solid; border-radius: 999px; padding: .12rem .55rem; font-weight: 650; font-size: .78rem; }
  .ar { color: var(--muted); }
  .imp { font-size: .78rem; margin: 0 0 .3rem; width: 100%; }
  .imp th, .imp td { padding: .25rem .3rem; text-align: right; font-variant-numeric: tabular-nums; }
  .imp thead th { font-size: .75rem; }
  .imp td.zero { color: var(--muted); background: color-mix(in srgb, var(--muted) 10%, transparent); }
  .note { font-size: .76rem; color: var(--muted); margin: .3rem 0 .6rem; }
  .verdict { margin: .2rem 0 .5rem; }
</style>
