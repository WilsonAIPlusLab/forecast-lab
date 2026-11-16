<script lang="ts">
  // IRF reader: turn an impulse-response chart into a sentence with units.
  // Pick the size of the surprise hike, the variable you report, and the quarter; the readout writes
  // the sentence a CFO can use, including what the 90% band says in words.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import raw from './var_extra.json';
  import { col } from './varlib';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';

  type Band = { pt: number[]; lo: number[]; hi: number[] };
  const R = (raw as any).reader as { shock_sd: number; infl: Band; unemp: Band; ffr: Band; price: Band };
  const SD = R.shock_sd;
  type Resp = 'unemp' | 'infl' | 'price' | 'ffr';
  const RESP: Record<Resp, { label: string; unit: string; color: string; what: string; units: string }> = {
    unemp: { label: 'Unemployment', unit: 'pp', color: 'unemp', what: 'the unemployment rate', units: 'Percentage points of the unemployment rate: +0.15 means, say, 4.00% becomes 4.15%.' },
    infl: { label: 'Inflation rate', unit: 'pp', color: 'infl', what: 'inflation (at an annual rate)', units: 'Percentage points of annualized quarterly inflation: +0.37 means, say, 3.00% becomes 3.37% at an annual rate, for that one quarter.' },
    price: { label: 'Price level', unit: '%', color: 'infl', what: 'the CPI level', units: 'Percent of the CPI level: the inflation responses added up and divided by 4 (because each one is an annualized quarterly rate).' },
    ffr: { label: 'Funds rate', unit: 'pp', color: 'ffr', what: 'the funds rate', units: 'Percentage points of the federal funds rate. At quarter 0 it equals the size of the surprise.' },
  };
  const SIZES = [
    { v: SD, label: `One s.d. (${SD.toFixed(2)} pp)` },
    { v: 0.25, label: '25 bp' },
    { v: 1, label: '1 pp' },
    { v: 2, label: '2 pp' },
  ];
  let size = $state(1);
  let resp: Resp = $state('unemp');
  let h = $state(8);
  let el: HTMLDivElement;

  const k = $derived(size / SD);
  const b = $derived(R[resp]);
  const pt = $derived(b.pt.map((v) => v * k));
  const lo = $derived(b.lo.map((v) => v * k));
  const hi = $derived(b.hi.map((v) => v * k));
  // fixed axis per response (at the largest shock), so a bigger surprise visibly makes a bigger response
  const dom = $derived.by(() => { const s = 2 / SD; const all = [...b.lo, ...b.hi, 0].map((v) => v * s); return [Math.min(...all), Math.max(...all)]; });
  const peak = $derived.by(() => { let j = 0; for (let i = 1; i < pt.length; i++) if (Math.abs(pt[i]) > Math.abs(pt[j])) j = i; return j; });

  const f = (v: number, d = 2) => (v > 0 ? '+' : v < 0 ? '−' : '') + Math.abs(v).toFixed(d);
  const dp = $derived(resp === 'price' || size === 0.25 ? 3 : 2);
  const u = (v: number) => (RESP[resp].unit === '%' ? `${f(v, dp)}%` : `${f(v, dp)} pp`);
  const when = (q: number) => (q === 0 ? 'in the quarter of the surprise' : `${q} quarter${q > 1 ? 's' : ''}${q % 4 === 0 ? ` (${q / 4} year${q > 4 ? 's' : ''})` : ''} later`);
  const sizeWords = $derived(size === SD ? `one-standard-deviation (${SD.toFixed(2)}-percentage-point)` : size === 0.25 ? '25-basis-point (0.25-percentage-point)' : `${size}-percentage-point`);
  const dir = (v: number) => (v >= 0 ? 'higher' : 'lower');
  const sentence = $derived.by(() => {
    const v = pt[h];
    if (h === 0 && resp !== 'ffr') return `${when(0)[0].toUpperCase() + when(0).slice(1)}, ${RESP[resp].what} does not move at all. That zero is an assumption, not a finding: with the Fed ordered last, prices and jobs cannot react to the Fed within the quarter.`;
    return `A ${sizeWords} surprise rise in the funds rate is followed, ${when(h)}, by ${RESP[resp].what} ${Math.abs(v).toFixed(dp)}${RESP[resp].unit === '%' ? '%' : ' percentage points'} ${dir(v)} than it would otherwise have been.`;
  });
  const bandWords = $derived.by(() => {
    if (h === 0 && resp !== 'ffr') return '';
    const l = lo[h], r = hi[h];
    const range = `90% band: ${u(l)} to ${u(r)}.`;
    if (l > 0) return `${range} The whole band is above zero: the data point clearly to a rise at this horizon.`;
    if (r < 0) return `${range} The whole band is below zero: the data point clearly to a fall at this horizon.`;
    return `${range} The band includes zero: at this horizon we cannot rule out no effect at all.`;
  });

  function draw() {
    if (!el) return;
    const W = el.clientWidth, narrow = W < 520;
    const c = col(RESP[resp].color);
    const rows = pt.map((v, i) => ({ h: i, v, lo: lo[i], hi: hi[i] }));
    el.replaceChildren(Plot.plot({
      width: W, height: 300, marginLeft: 52, marginRight: narrow ? 14 : 24, marginBottom: 38, style: plotStyle(),
      x: { domain: [0, 20], ticks: [0, 4, 8, 12, 16, 20], label: 'quarters after the surprise hike', labelAnchor: 'right' },
      y: { domain: dom, nice: true, grid: true, label: RESP[resp].unit === '%' ? '% vs. no hike' : 'pp vs. no hike', tickFormat: (d: number) => (d > 0 ? '+' : '') + d },
      ariaLabel: `Response of ${RESP[resp].label} to a ${size.toFixed(2)} percentage point surprise rise in the funds rate, quarters 0 to 20, with 90% band`,
      marks: [
        Plot.areaY(rows, { x: 'h', y1: 'lo', y2: 'hi', fill: c, fillOpacity: 0.18, curve: 'monotone-x' }),
        Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
        Plot.lineY(rows, { x: 'h', y: 'v', stroke: c, strokeWidth: 2.5, curve: 'monotone-x' }),
        Plot.ruleX([h], { stroke: C.text, strokeWidth: 1.5, strokeDasharray: '4,3' }),
        Plot.ruleX([h], { y1: lo[h], y2: hi[h], stroke: c, strokeWidth: 5, strokeOpacity: 0.55 }),
        Plot.dot([rows[peak]], { x: 'h', y: 'v', r: 5, fill: C.surface, stroke: c, strokeWidth: 2 }),
        Plot.text([rows[peak]], { x: 'h', y: 'v', text: () => `peak ${u(pt[peak])}, quarter ${peak}`, dy: pt[peak] >= 0 ? -14 : 16, dx: peak > 12 ? -6 : 6, fill: c, stroke: C.surface, strokeWidth: 4, paintOrder: 'stroke', fontWeight: 650, fontSize: 12, textAnchor: peak > 12 ? 'end' : 'start' }),
        Plot.dot([rows[h]], { x: 'h', y: 'v', r: 5, fill: c, stroke: C.surface, strokeWidth: 2 }),
        Plot.tip(rows, Plot.pointerX({ x: 'h', y: 'v', title: (d: any) => `Quarter ${d.h}\n${RESP[resp].label}: ${u(d.v)}\n90% band: ${u(d.lo)} to ${u(d.hi)}` })),
      ],
    }));
  }
  $effect(() => { pt; h; resp; dom; draw(); });
  onMount(() => watchLayout(el, draw));
</script>

<Explorable title="Read an impulse response out loud: size, units, timing and band"
  caption={`Choose how big the surprise hike is, which variable you report, and the quarter. The readout turns the chart into the sentence you would say to a manager. Responses are linear, so a bigger surprise scales the whole path (band included, approximately) without changing its shape; the vertical axis stays fixed so you can see it grow. Baseline ordering (Fed last), VAR(4), 1960Q1–2000Q4, 90% bootstrap bands from 300 runs. Data: FRED (CPIAUCSL, UNRATE, FEDFUNDS).`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Size of the surprise hike">
      {#each SIZES as s}<button class:on={size === s.v} onclick={() => (size = s.v)}>{s.label}</button>{/each}
    </div>
    <div class="seg" role="group" aria-label="Variable to report">
      {#each Object.keys(RESP) as r}<button class:on={resp === r} onclick={() => (resp = r as Resp)}>{RESP[r as Resp].label}</button>{/each}
    </div>
    <label class="sl">Quarter <input type="range" min="0" max="20" bind:value={h} aria-valuetext={`${h} quarters after the hike`} /> <b>{h}</b></label>
  {/snippet}
  {#snippet aside()}
    <div class="ro" aria-live="polite">
      <div class="lbl">Say it in words</div>
      <p class="say">{sentence}</p>
      {#if bandWords}<p class="band">{bandWords}</p>{/if}
      <p class="pk">Largest move: <b style:color={col(RESP[resp].color)}>{u(pt[peak])}</b>, {when(peak)}.</p>
      <p class="un"><b>Units.</b> {RESP[resp].units}</p>
    </div>
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 300px; }
  .ro { font-size: .84rem; line-height: 1.45; }
  .lbl { font-size: .75rem; color: var(--muted); font-weight: 650; margin-bottom: .4rem; text-transform: uppercase; letter-spacing: .04em; }
  .say { margin: 0 0 .6rem; color: var(--text); font-weight: 550; }
  .band, .pk { margin: 0 0 .55rem; color: var(--text-2); font-variant-numeric: tabular-nums; }
  .un { margin: .7rem 0 0; padding-top: .55rem; border-top: 1px solid var(--border); color: var(--text-2); font-size: .8rem; }
</style>
