<script lang="ts">
  // Explorable: what a fitted alpha does to a one-off surprise vs a lasting change.
  // A stylized, noise-free product (100 thousand units a month) so the pure SES response is visible.
  // Left: a one-time spike (a bulk order). Right: a permanent step (a competitor closes).
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';

  const BASE = 100, SPIKE = 60, STEP = 30, PRE = 4, POST = 18;
  let alpha = $state(0.3);
  let compare = $state(true);
  let elA: HTMLDivElement, elB: HTMLDivElement;

  const months = Array.from({ length: PRE + POST + 1 }, (_, i) => i - PRE);   // month -4 ... 18; event at 0
  const spikeY = months.map((m) => (m === 0 ? BASE + SPIKE : BASE));
  const stepY = months.map((m) => (m >= 0 ? BASE + STEP : BASE));

  /** One-step SES forecasts: forecast for month i is the level after month i-1 (level starts at 100). */
  function sesPath(y: number[], a: number) {
    let l = BASE; const f: number[] = [];
    for (const v of y) { f.push(l); l = a * v + (1 - a) * l; }
    return f;
  }

  // plain-language read-outs (all closed-form)
  const r = $derived.by(() => {
    const k = 1 - alpha;
    return {
      next: SPIKE * alpha,                                  // extra units in next month's forecast
      phantom: SPIKE * (1 - k ** 12),                       // extra units forecast over the next 12 months
      catch90: alpha >= 1 ? 1 : Math.ceil(Math.log(0.1) / Math.log(k)),   // months until 90% of the step is absorbed
      missed: alpha >= 1 ? STEP : (STEP * (1 - k ** 12)) / alpha,         // units under-forecast in the 12 months from the shift
    };
  });

  function chart(el: HTMLDivElement, y: number[], title: string, at: number, dy: number) {
    if (!el) return;
    const W = el.clientWidth;
    if (W < 200) return;                      // skip transient tiny widths (e.g. mid-resize)
    const rows = (f: number[]) => months.map((m, i) => ({ m, v: f[i] }));
    const act = months.map((m, i) => ({ m, v: y[i] }));
    const cur = rows(sesPath(y, alpha));
    const ghosts = compare ? [0.1, 0.9].filter((a) => Math.abs(a - alpha) > 0.04).map((a) => ({ a, d: rows(sesPath(y, a)) })) : [];
    const lab = (d: any, txt: string, fill: string, dy = 0) => Plot.text([d], { x: 'm', y: 'v', text: () => txt, dx: 5, dy, textAnchor: 'start', fill, fontSize: 12, fontWeight: 650, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' } as any);
    const pick = (d: any[]) => d[PRE + at];   // label each forecast line where the lines are far apart
    const marks: any[] = [
      Plot.ruleX([0], { stroke: C.borderStrong, strokeDasharray: '3 4' }),
      Plot.lineY(act, { x: 'm', y: 'v', stroke: C.history, strokeWidth: 2, curve: 'step-after' }),
      Plot.dot(act, { x: 'm', y: 'v', fill: C.history, r: 2.2 }),
      ...ghosts.map((g) => Plot.lineY(g.d, { x: 'm', y: 'v', stroke: C.muted, strokeWidth: 1.25, strokeOpacity: 0.6, strokeDasharray: '3 3' })),
      ...ghosts.map((g) => lab(pick(g.d), `α = ${g.a}`, C.muted, dy)),
      Plot.lineY(cur, { x: 'm', y: 'v', stroke: C.forecast, strokeWidth: 3 }),
      lab(pick(cur), `α = ${alpha.toFixed(2)}`, C.forecast, dy),
      Plot.tip(cur.map((d, i) => ({ ...d, a: y[i] })), Plot.pointerX({ x: 'm', y: 'v', title: (d: any) => `Month ${d.m >= 0 ? '+' : ''}${d.m}\nActual: ${d.a.toFixed(0)} thousand units\nSES forecast (α = ${alpha.toFixed(2)}): ${d.v.toFixed(1)} thousand units` })),
    ];
    const c = Plot.plot({
      width: W, height: 240, marginLeft: 40, marginRight: 20, marginTop: 26, marginBottom: 32,
      style: { ...plotStyle(), fontSize: '12px' },
      x: { label: 'months after the event', labelAnchor: 'right', labelOffset: 28, ticks: 6 },
      y: { domain: [90, BASE + SPIKE + 4], grid: true, label: '↑ thousand units', ticks: 4 },
      ariaLabel: `${title}: actual sales and the simple exponential smoothing forecast at alpha ${alpha.toFixed(2)}`,
      marks,
    });
    el.replaceChildren(c);
  }
  function draw() {
    chart(elA, spikeY, 'One-off spike', 1, -8);    // label lines at month 1, above them
    chart(elB, stepY, 'Lasting shift', 2, 12);     // label lines at month 2, below them
  }
  $effect(() => { alpha; compare; draw(); });
  onMount(() => { const a = watchLayout(elA, draw); return a; });
</script>

<Explorable title="One surprise, two stories: no α handles both" caption={`A <b>stylized</b> product that sells exactly 100 thousand units a month, with no noise, so you see only how simple exponential smoothing reacts. <b>Left:</b> one month jumps to 160 (a one-time bulk order), then sales return to normal. <b>Right:</b> sales step up to 130 and stay there (a competitor closes). The violet line is the forecast SES makes each month for that month, from the data before it. Drag <b>α</b> and compare the two read-outs.`}>
  {#snippet controls()}
    <label class="sl">α <input type="range" min="0.05" max="1" step="0.01" bind:value={alpha} aria-label="Smoothing parameter alpha" aria-valuetext={`alpha ${alpha.toFixed(2)}`} /> <b>{alpha.toFixed(2)}</b></label>
    <label class="ck"><input type="checkbox" bind:checked={compare} /> Show α = 0.1 and 0.9 for comparison</label>
  {/snippet}
  {#snippet aside()}
    <div class="ro" aria-live="polite">
      <div class="blk">
        <div class="h">One-off spike (+60)</div>
        <div class="stat"><span class="stat-v">+{r.next.toFixed(1)}</span><span class="stat-l">thousand units added to next month's forecast (60 × α)</span></div>
        <div class="stat"><span class="stat-v">+{r.phantom.toFixed(0)}</span><span class="stat-l">thousand phantom units forecast over the next 12 months</span></div>
      </div>
      <div class="blk">
        <div class="h">Lasting shift (+30)</div>
        <div class="stat"><span class="stat-v">{r.catch90}</span><span class="stat-l">{r.catch90 === 1 ? 'month' : 'months'} until the forecast has absorbed 90% of the shift</span></div>
        <div class="stat"><span class="stat-v">{r.missed.toFixed(0)}</span><span class="stat-l">thousand units under-forecast in the 12 months from the shift</span></div>
      </div>
      <p class="verdict">
        {#if alpha >= 0.7}A high α adopts the new shift almost at once, but it also books most of a one-off spike as if it were permanent.
        {:else if alpha <= 0.2}A low α shrugs off the spike, but it takes many months to believe a real change.
        {:else}A middle α splits the difference: it is partly fooled by the spike and partly slow on the shift.{/if}
      </p>
    </div>
  {/snippet}
  <div class="pair">
    <div><div class="ttl">One-off spike <span>a one-time bulk order: 160 for one month</span></div><div bind:this={elA} class="chart"></div></div>
    <div><div class="ttl">Lasting shift <span>a competitor closes: 130 from month 0 on</span></div><div bind:this={elB} class="chart"></div></div>
  </div>
</Explorable>

<style>
  .pair { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
  @media (max-width: 640px) { .pair { grid-template-columns: 1fr; } }
  .ttl { font-size: .84rem; font-weight: 650; color: var(--text); margin-bottom: .1rem; }
  .ttl span { display: block; font-weight: 400; font-size: .78rem; color: var(--muted); }
  .chart { min-height: 240px; }
  .ro { display: grid; gap: .9rem; font-size: .84rem; }
  .blk { display: grid; gap: .5rem; }
  .h { font-weight: 650; color: var(--text); font-size: .82rem; }
  .verdict { color: var(--text-2); margin: 0; line-height: 1.5; }
  .ck { display: inline-flex; align-items: center; gap: .4rem; cursor: pointer; }
  .ck input { accent-color: var(--accent); }
</style>
