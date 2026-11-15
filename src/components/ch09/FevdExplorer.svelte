<script lang="ts">
  // FEVD explorer: what share of a variable's forecast error comes from each shock, by horizon.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { D, BASE, META, col, type VarKey } from './varlib';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';

  const K: VarKey[] = ['infl', 'unemp', 'ffr'];
  const ORD = { last: BASE, first: 'ffr,infl,unemp' } as const;
  let res: VarKey = $state('unemp');
  let o: keyof typeof ORD = $state('last');
  let h = $state(8);
  const fe = $derived(D.fevd[ORD[o]][res]);
  const at = $derived(K.map((s) => ({ s, v: fe[s][h - 1] })));
  let el: HTMLDivElement;

  function draw() {
    if (!el) return;
    const rows = K.flatMap((s) => fe[s].map((v, i) => ({ h: i + 1, v: 100 * v, s })));
    const W = el.clientWidth, narrow = W < 560;
    let cum = 0;
    const lab = K.map((s) => { const v = 100 * fe[s][19]; const y = cum + v / 2; cum += v; return { s, y, v }; });
    el.replaceChildren(Plot.plot({
      width: W, height: 300, marginLeft: 44, marginRight: narrow ? 12 : 128, marginBottom: 36, style: plotStyle(),
      x: { domain: [1, 20], ticks: [1, 4, 8, 12, 16, 20], label: 'forecast horizon (quarters ahead)', labelAnchor: 'right' },
      y: { domain: [0, 100], grid: true, label: '% of forecast error variance' },
      ariaLabel: `Forecast error variance decomposition of ${META[res].label}`,
      marks: [
        Plot.areaY(rows, { x: 'h', y: 'v', z: 's', order: K, fill: (d: any) => col(d.s), fillOpacity: 0.8, stroke: C.surface, strokeWidth: 1, curve: 'monotone-x' }),
        Plot.ruleX([h], { stroke: C.text, strokeWidth: 2, strokeDasharray: '4,3' }),
        narrow ? null : Plot.text(lab.filter((d) => d.v > 4), { x: 20, y: 'y', text: (d: any) => `${META[d.s as VarKey].short} shocks`, dx: 8, textAnchor: 'start', fill: (d: any) => col(d.s), fontWeight: 650, fontSize: 12 }),
      ],
    }));
  }
  $effect(() => { fe; h; draw(); });
  onMount(() => watchLayout(el, draw));
  const top = $derived([...at].sort((a, b) => b.v - a.v)[0]);
</script>

<Explorable title="Where do forecast errors come from? It depends on how far ahead you look"
  caption={`Choose the variable you are forecasting and drag the horizon. The stacked areas split its <i>h</i>-quarter-ahead forecast error variance among the three orthogonalized shocks; each column sums to 100%. Switch the ordering to see that the FEVD inherits the identification problem. VAR(4), 1960Q1–2000Q4.`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Variable being forecast">
      {#each K as k}<button class:on={res === k} onclick={() => (res = k)}>{META[k].label}</button>{/each}
    </div>
    <div class="seg" role="group" aria-label="Cholesky ordering">
      <button class:on={o === 'last'} onclick={() => (o = 'last')}>Fed last</button><button class:on={o === 'first'} onclick={() => (o = 'first')}>Fed first</button>
    </div>
    <label class="sl">Horizon <input type="range" min="1" max="20" bind:value={h} aria-valuetext={`${h} quarters ahead`} /> <b>{h} q</b></label>
  {/snippet}
  {#snippet aside()}
    <div class="ro" aria-live="polite">
      <div class="lbl">{META[res].label}, {h} quarter{h > 1 ? 's' : ''} ahead</div>
      {#each at as d}
        <div class="row">
          <span class="nm" style:color={col(d.s)}>{META[d.s].short} shocks</span>
          <span class="bar"><i style:width={`${100 * d.v}%`} style:background={col(d.s)}></i></span>
          <b>{(100 * d.v).toFixed(0)}%</b>
        </div>
      {/each}
      <p class="sum">The largest source is <b style:color={col(top.s)}>{META[top.s].label.toLowerCase()}</b> shocks. Funds-rate surprises explain {(100 * fe.ffr[h - 1]).toFixed(0)}%.</p>
    </div>
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 300px; }
  .ro { font-size: .82rem; }
  .lbl { font-size: .75rem; color: var(--muted); font-weight: 650; margin-bottom: .5rem; }
  .row { display: grid; grid-template-columns: 7.5em 1fr 3em; gap: .5rem; align-items: center; margin: .35rem 0; font-variant-numeric: tabular-nums; }
  .nm { font-weight: 650; }
  .bar { height: 10px; background: var(--surface-3); border-radius: 3px; overflow: hidden; }
  .bar i { display: block; height: 100%; }
  .row b { text-align: right; color: var(--text); }
  .sum { color: var(--text-2); margin: .7rem 0 0; }
</style>
