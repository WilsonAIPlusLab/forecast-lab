<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { monthName, HIER, hierarchyForecasts } from './lib';

  const { BOTTOM, NODES, LABEL, METHODS, H } = HIER;
  type MK = (typeof METHODS)[number]['k'];

  let method: MK = $state('base');
  let hz = $state(1);
  let res: any = $state(null);
  let elGap: HTMLDivElement, elTree: HTMLDivElement;
  let W = $state(800);

  onMount(async () => { res = await hierarchyForecasts(); W = elTree?.clientWidth || W; });

  const best = $derived.by(() => {
    if (!res) return {} as Record<string, string>;
    const o: Record<string, string> = {};
    for (const c of ['total', 'ex', 'bot']) o[c] = METHODS.map((m) => m.k).sort((a, b) => res.score[a][c] - res.score[b][c])[0];
    return o;
  });

  function drawGap() {
    if (!res || !elGap) return;
    const rows = METHODS.flatMap((m) => res.gap[m.k].map((g: number, h: number) => ({ h: h + 1, g, m: m.k, on: m.k === method })));
    elGap.replaceChildren(Plot.plot({
      width: elGap.clientWidth, height: 170, marginLeft: 56, marginRight: 12, marginBottom: 32, style: plotStyle(),
      x: { label: 'Months ahead →', ticks: 12 }, y: { grid: true, label: 'Total minus sum of parts, $ millions', tickFormat: (v: number) => v.toLocaleString('en-US') },
      marks: [
        Plot.ruleY([0], { stroke: C.good, strokeWidth: 2 }),
        Plot.text([{ h: 12, g: 0 }], { x: 'h', y: 'g', text: () => 'adds up', dy: -8, textAnchor: 'end', fill: C.good, fontSize: 12 }),
        Plot.lineY(rows.filter((r) => r.m === 'base'), { x: 'h', y: 'g', stroke: C.danger, strokeWidth: method === 'base' ? 3 : 1.5, strokeOpacity: method === 'base' ? 1 : 0.4 }),
        Plot.dot(rows.filter((r) => r.on), { x: 'h', y: 'g', r: (r: any) => (r.h === hz ? 6 : 3), fill: method === 'base' ? C.danger : C.good }),
        Plot.tip(rows.filter((r) => r.on), Plot.pointerX({ x: 'h', y: 'g', title: (r: any) => `${r.h} month(s) ahead\nTotal − sum of parts: ${Math.round(r.g).toLocaleString('en-US')} $ millions` })),
      ],
    }));
  }
  $effect(() => { res; method; hz; drawGap(); });
  onMount(() => watchLayout(elTree, () => { W = elTree.clientWidth; drawGap(); }));

  // ── tree layout ──
  const lay = $derived.by(() => {
    const w = Math.max(320, W);
    const narrow = w < 1000;
    const per = narrow ? 5 : 10;
    const bw = Math.min(118, (w - 8) / per - 6), bh = 50;
    const kids = BOTTOM.slice(1);
    const pos: Record<string, { x: number; y: number }> = {};
    pos.Total = { x: w / 2, y: 30 };
    pos.Motor_vehicles = { x: w * 0.16, y: 120 };
    pos.Ex_autos = { x: w * 0.6, y: 120 };
    kids.forEach((k, i) => { const row = Math.floor(i / per), col = i % per; const n = Math.min(per, kids.length - row * per); const span = (w - 8) / per; pos[k] = { x: 4 + span * (col + 0.5) + ((per - n) * span) / 2, y: 210 + row * (bh + 16) }; });
    const height = 210 + Math.ceil(kids.length / per) * (bh + 16) + 6;
    return { w, bw, bh, pos, height, kids };
  });
  const val = (k: string) => (res ? res.F[method][k][hz - 1] : 0);
  const act = (k: string) => (res ? res.act[k][hz - 1] : 0);
  const err = (k: string) => (100 * (act(k) - val(k))) / act(k);
  const bn = (v: number) => (v / 1000).toFixed(1);
  const sumKids = (k: string) => (k === 'Total' ? BOTTOM : BOTTOM.slice(1)).reduce((s, b) => s + val(b), 0);
</script>

<Explorable title="The hierarchy machine: make 13 forecasts add up" caption={`Every box is a forecast of retail sales for one month of the test period (seasonally adjusted, $ billions per month). Each series gets a damped-Holt model fit through ${res ? monthName(res.lastTrain) : 'the training period'}. The code lab uses ets(), so its numbers differ a little. Pick a method: <b>Base</b> forecasts each series on its own, so the parts don't add up (red gap). The other four methods force coherence in different ways. Box color and sign show the % miss against what actually happened. Data: FRED (RSAFS, RSFSXMV, RSMVPD + 9 categories).`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Method">
      {#each METHODS as m}<button class:on={method === m.k} aria-pressed={method === m.k} onclick={() => (method = m.k)}>{m.label}</button>{/each}
    </div>
    {#if res}<label class="sl">Month <input type="range" min="1" max={H} bind:value={hz} aria-valuetext={`${hz} months ahead`} /> <b>{monthName(res.testDates[hz - 1])}</b></label>{/if}
  {/snippet}
  {#snippet aside()}
    {#if res}
      <div class="side">
        <div class="eyebrow">Accuracy over all 12 test months (MAPE, %)</div>
        <table>
          <thead><tr><th>Method</th><th>Total</th><th>Ex-autos</th><th title="Average across the 11 bottom-level categories">Parts</th></tr></thead>
          <tbody>
            {#each METHODS as m}
              <tr class:on={method === m.k} onclick={() => (method = m.k)} tabindex="0" onkeydown={(e) => e.key === 'Enter' && (method = m.k)}>
                <td>{m.label.replace(' (independent)', '').replace(' reconcile', '')}</td>
                <td class:best={best.total === m.k}>{res.score[m.k].total.toFixed(2)}</td>
                <td class:best={best.ex === m.k}>{res.score[m.k].ex.toFixed(2)}</td>
                <td class:best={best.bot === m.k}>{res.score[m.k].bot.toFixed(2)}</td>
              </tr>
            {/each}
          </tbody>
        </table>
        <p class="hint">Green = best in column. Only <b>Base</b> fails to add up. The best method for the total is not the best for the parts. One 12-month test is a single draw, so treat the ranking as suggestive.</p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={elTree} class="treebox">
    {#if res}
      <svg width={lay.w} height={lay.height} role="img" aria-label={`Retail sales hierarchy, ${METHODS.find((m) => m.k === method)?.label} forecasts for ${monthName(res.testDates[hz - 1])}`}>
        {#each [['Total', 'Motor_vehicles'], ['Total', 'Ex_autos'], ...lay.kids.map((k) => ['Ex_autos', k])] as [a, b]}
          <path d={`M${lay.pos[a].x},${lay.pos[a].y + lay.bh / 2} C${lay.pos[a].x},${(lay.pos[a].y + lay.pos[b].y) / 2 + 10} ${lay.pos[b].x},${(lay.pos[a].y + lay.pos[b].y) / 2} ${lay.pos[b].x},${lay.pos[b].y - lay.bh / 2}`} class="edge" />
        {/each}
        {#each NODES as k}
          {@const p = lay.pos[k]}
          {@const e = err(k)}
          {@const parent = k === 'Total' || k === 'Ex_autos'}
          {@const gap = parent ? val(k) - sumKids(k) : 0}
          <g transform={`translate(${p.x - (parent ? 80 : lay.bw / 2)}, ${p.y - lay.bh / 2})`}>
            <rect width={parent ? 160 : lay.bw} height={lay.bh} rx="7" class="node" class:bad={parent && Math.abs(gap) > 1} style={`--e:${Math.min(1, Math.abs(e) / 6)}`} data-sign={e >= 0 ? 'under' : 'over'} />
            <text x={(parent ? 160 : lay.bw) / 2} y="15" class="nm">{parent ? LABEL[k] : LABEL[k].length > 14 && lay.bw < 100 ? LABEL[k].split(/[ (&]/)[0] : LABEL[k]}</text>
            <text x={(parent ? 160 : lay.bw) / 2} y="31" class="vv">${bn(val(k))}bn</text>
            <text x={(parent ? 160 : lay.bw) / 2} y="44" class="ee" class:under={e >= 0}>{e >= 0 ? 'under by ' : 'over by '}{Math.abs(e).toFixed(1)}%</text>
            {#if parent && Math.abs(gap) > 1}
              <text x={160 + 6} y="20" class="gap">parts sum to ${bn(sumKids(k))}bn</text>
              <text x={160 + 6} y="35" class="gap">gap {gap > 0 ? '+' : '−'}${(Math.abs(gap) / 1000).toFixed(2)}bn</text>
            {:else if parent}
              <text x={160 + 6} y="28" class="ok">✓ parts add up</text>
            {/if}
          </g>
        {/each}
      </svg>
    {:else}<p class="load">Fitting 13 forecasts…</p>{/if}
  </div>
  <div class="eyebrow" style="margin-top:.8rem">Coherence gap by horizon: Total forecast minus the sum of its 11 parts</div>
  <div bind:this={elGap}></div>
</Explorable>

<style>
  .treebox { min-height: 300px; overflow-x: auto; }
  svg { display: block; overflow: visible; }
  .edge { fill: none; stroke: var(--border-strong); stroke-width: 1.25; }
  .node { fill: color-mix(in srgb, var(--c-s1) calc(var(--e) * 30%), var(--bg-2)); stroke: var(--border-strong); stroke-width: 1; transition: fill .3s; }
  .node[data-sign='over'] { fill: color-mix(in srgb, var(--c-s2) calc(var(--e) * 30%), var(--bg-2)); }
  .node.bad { stroke: var(--danger); stroke-width: 2; stroke-dasharray: 4 3; }
  text { text-anchor: middle; font-family: var(--font-ui); }
  .nm { font-size: 11.5px; fill: var(--text-2); font-weight: 600; }
  .vv { font-size: 12.5px; fill: var(--text); font-weight: 700; font-variant-numeric: tabular-nums; }
  .ee { font-size: 11px; fill: var(--c-s2); font-variant-numeric: tabular-nums; }
  .ee.under { fill: var(--c-s1); }
  .gap { text-anchor: start; font-size: 12px; fill: var(--danger); font-weight: 650; }
  .ok { text-anchor: start; font-size: 12px; fill: var(--good); font-weight: 650; }
  .side { font-size: .82rem; }
  .side table { margin: .5rem 0 .7rem; font-size: .78rem; width: 100%; }
  .side th, .side td { padding: .32rem .3rem; }
  .side td { font-variant-numeric: tabular-nums; }
  .side tr { cursor: pointer; }
  .side tr.on { background: var(--surface-2); }
  .side tr.on td:first-child { color: var(--text); font-weight: 650; }
  .side td.best { color: var(--good); font-weight: 700; }
  .hint { color: var(--muted); font-size: .76rem; margin: 0; }
  .load { color: var(--muted); }
  @media (prefers-reduced-motion: reduce) { .node { transition: none; } }
</style>
