<script lang="ts">
  import { onMount, tick } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { PANEL, loadPanel, loadRecessions, pca, reduceMotion } from './lib';

  let mode: 'wall' | 'factor' = $state('wall');
  let clip = $state(true);
  let data: Awaited<ReturnType<typeof loadPanel>> | null = $state(null);
  let rec: { a: Date; b: Date }[] = [];
  let wrap: HTMLDivElement, elBig: HTMLDivElement;
  let elScree: HTMLDivElement | undefined = $state();
  let cells: HTMLDivElement[] = $state([]);
  let offsets: string[] = $state([]);

  onMount(async () => {
    [data, rec] = await Promise.all([loadPanel(), loadRecessions()]);
  });

  const res = $derived.by(() => {
    if (!data) return null;
    const P = pca(data.X, clip ? 4 : null);
    let w = P.vectors[0];
    if (w[0] < 0) w = w.map((v) => -v); // payrolls load positively: "up" = stronger economy
    const f = P.Z.map((r) => r.reduce((s, v, j) => s + v * w[j], 0));
    const ma3 = f.map((_, i) => (i < 2 ? NaN : (f[i] + f[i - 1] + f[i - 2]) / 3));
    // 6-month averages of each standardized series for the sparkline wall (display only; smoother, so cycles show)
    const sm = PANEL.map((_, j) => P.Z.map((_r, i) => { if (i < 5) return NaN; let a = 0; for (let k = 0; k < 6; k++) a += P.Z[i - k][j]; return a / 6; }));
    const top = PANEL.map((p, j) => ({ label: p.label, w: w[j] })).sort((a, b) => Math.abs(b.w) - Math.abs(a.w));
    return { share: P.share, w, ma3, sm, top, clipped: P.clipped, cells: data.X.length * PANEL.length };
  });

  function spark(el: HTMLElement, j: number) {
    if (!res || !data || !el) return;
    const rows = data.dates.map((d, i) => ({ d, v: res.sm[j][i] })).filter((r) => Number.isFinite(r.v));
    const W = el.clientWidth || 160;
    const neg = res.w[j] < -0.05;
    el.replaceChildren(Plot.plot({
      width: W, height: 54, margin: 2, marginLeft: 2, style: plotStyle(), x: { axis: null }, y: { axis: null, domain: [-2.5, 2.5], clamp: true },
      marks: [
        Plot.rectX(rec.filter((r) => +r.b >= +data!.dates[0]), { x1: 'a', x2: 'b', fill: C.muted, fillOpacity: 0.16 }),
        Plot.ruleY([0], { stroke: C.border }),
        Plot.lineY(rows, { x: 'd', y: 'v', stroke: neg ? C.s[1] : C.history, strokeWidth: 1.25, clip: true }),
      ],
    }));
  }

  function drawWall() { cells.forEach((c, j) => c && spark(c.querySelector('.sp') as HTMLElement, j)); }

  function drawBig() {
    if (!res || !data || !elBig) return;
    const W = elBig.clientWidth;
    const ctx = PANEL.flatMap((p, j) => data!.dates.map((d, i) => ({ d, v: res.sm[j][i] * Math.sign(res.w[j]), id: p.id }))).filter((r) => Number.isFinite(r.v));
    const fac = data.dates.map((d, i) => ({ d, v: res.ma3[i] })).filter((r) => Number.isFinite(r.v));
    const ext = Math.max(...fac.map((r) => Math.abs(r.v)));
    const low = fac.reduce((a, b) => (b.v < a.v ? b : a));
    const ch = Plot.plot({
      width: W, height: 330, marginLeft: 44, marginRight: 16, marginTop: 18, style: plotStyle(),
      x: { label: null }, y: { grid: true, label: 'Activity factor, 3-month average (standard units)', domain: [-ext * 1.08, Math.max(3, ext * 0.45)] },
      marks: [
        Plot.rectX(rec.filter((r) => +r.b >= +data!.dates[0]), { x1: 'a', x2: 'b', fill: C.muted, fillOpacity: 0.16 }),
        Plot.lineY(ctx, { x: 'd', y: 'v', z: 'id', stroke: C.history, strokeWidth: 1.25, strokeOpacity: 0.18, clip: true }),
        Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
        Plot.lineY(fac, { x: 'd', y: 'v', stroke: C.fitted, strokeWidth: 3 }),
        Plot.text([low], { x: 'd', y: 'v', text: (r: any) => `${r.d.getFullYear()}: ${r.v.toFixed(1)}`, dx: 8, textAnchor: 'start', fill: C.text, fontWeight: 650, fontSize: 12, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' } as any),
        Plot.text([{ d: rec.find((r) => r.a.getFullYear() === 2008)?.a ?? data.dates[0] }], { x: 'd', frameAnchor: 'top', dy: -12, textAnchor: 'start', text: () => 'grey = NBER recession', fill: C.muted, fontSize: 12 }),
        Plot.tip(fac, Plot.pointerX({ x: 'd', y: 'v', title: (r: any) => `${r.d.toLocaleDateString('en-US', { month: 'short', year: 'numeric' })}\nFactor (3-mo avg): ${r.v.toFixed(2)} standard units` })),
      ],
    });
    ch.setAttribute('aria-label', `The first principal component of 20 indicators, 1993 to 2026, falls sharply in each recession. Its lowest 3-month average is ${low.v.toFixed(1)} in ${low.d.getFullYear()}.`);
    elBig.replaceChildren(ch);
  }

  function drawScree() {
    if (!res || !elScree) return;
    const d = res.share.slice(0, 6).map((s, i) => ({ k: `PC ${i + 1}`, s: 100 * s, i }));
    elScree.replaceChildren(Plot.plot({
      width: elScree.clientWidth || 250, height: 150, marginLeft: 40, marginBottom: 26, marginTop: 14, style: plotStyle(),
      x: { domain: d.map((r) => r.k), label: null, tickSize: 0 }, y: { grid: true, label: '% of variance', domain: [0, 55] },
      marks: [
        Plot.barY(d, { x: 'k', y: 's', fill: (r: any) => (r.i === 0 ? C.fitted : C.history), fillOpacity: (r: any) => (r.i === 0 ? 1 : 0.45), rx: 3 }),
        Plot.text(d, { x: 'k', y: 's', text: (r: any) => r.s.toFixed(0), dy: -7, fill: C.text2, fontSize: 12 }),
      ],
    }));
  }

  // FLIP-style collapse: every tile slides toward the centre of the wall and fades as the factor appears.
  async function computeOffsets() {
    await tick();
    if (!wrap) return;
    const box = wrap.getBoundingClientRect();
    offsets = cells.map((c) => {
      if (!c) return '';
      const r = c.getBoundingClientRect();
      return `translate(${box.left + box.width / 2 - (r.left + r.width / 2)}px, ${box.top + box.height / 2 - (r.top + r.height / 2)}px) scale(.35)`;
    });
  }
  async function toggle() { if (mode === 'wall') await computeOffsets(); mode = mode === 'wall' ? 'factor' : 'wall'; }

  $effect(() => { res; mode; tick().then(() => { drawWall(); drawBig(); drawScree(); }); });
  onMount(() => watchLayout(wrap, () => { drawWall(); drawBig(); drawScree(); }));

  const pct = (v: number) => (100 * v).toFixed(0) + '%';
</script>

<Explorable title="Twenty indicators, one heartbeat" caption={`Each tile is one monthly indicator from 1993 to 2026, standardized and smoothed with a 6-month average. Rose tiles, marked <i>↑ in downturns</i>, move against the cycle: jobless claims, credit spreads, financial stress. Press <b>Extract the common factor</b> to collapse the wall into its first principal component. Then turn off <b>Clip outliers</b> to see what a single month, April 2020, does to the analysis. Data: FRED, 20 series; grey = NBER recessions.`}>
  {#snippet controls()}
    <button class="btn btn-sm" onclick={toggle} aria-pressed={mode === 'factor'}>{mode === 'wall' ? 'Extract the common factor' : 'Back to the 20 series'}</button>
    <label class="ck"><input type="checkbox" bind:checked={clip} /> Clip outliers at ±4 SD</label>
  {/snippet}
  {#snippet aside()}
    {#if res}
      <div class="side" aria-live="polite">
        <div class="eyebrow">Scree plot: variance explained</div>
        <div bind:this={elScree}></div>
        <p class="note"><b>PC 1 explains {pct(res.share[0])}</b> of the variation in 20 series. The next component explains {pct(res.share[1])}.
          {#if clip}{res.clipped} of {res.cells.toLocaleString('en-US')} values were clipped, most of them in 2020.{:else}<span class="warn">Without clipping, COVID inflates PC 1. It now partly measures "was it spring 2020?"</span>{/if}</p>
        <div class="eyebrow" style="margin-top:.6rem">Largest weights in PC 1</div>
        <ul class="ld">
          {#each res.top.slice(0, 5) as t}<li><span>{t.label}</span><b class:neg={t.w < 0}>{t.w >= 0 ? '+' : '−'}{Math.abs(t.w).toFixed(2)}</b></li>{/each}
        </ul>
      </div>
    {/if}
  {/snippet}
  <div class="wall-wrap" bind:this={wrap}>
    <div class="wall" class:gone={mode === 'factor'} aria-hidden={mode === 'factor'}>
      {#each PANEL as p, j}
        <div class="tile" bind:this={cells[j]} style={mode === 'factor' ? `transform:${offsets[j] ?? ''}` : ''}>
          <div class="tl"><span>{p.label}</span><span class="g" class:neg={!!res && res.w[j] < -0.05}>{res && res.w[j] < -0.05 ? '↑ in downturns' : p.group}</span></div>
          <div class="sp" role="img" aria-label={`${p.label}, standardized monthly change`}></div>
        </div>
      {/each}
    </div>
    <div class="big" class:show={mode === 'factor'} bind:this={elBig} aria-hidden={mode === 'wall'}></div>
    {#if !data}<p class="load">Loading 20 series…</p>{/if}
  </div>
</Explorable>

<style>
  .wall-wrap { position: relative; min-height: 340px; }
  .wall { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 6px; }
  .tile { border: 1px solid var(--border); border-radius: 8px; padding: .3rem .45rem .15rem; background: var(--bg-2); transition: transform .5s cubic-bezier(.2, 0, 0, 1), opacity .45s; }
  .wall.gone .tile { opacity: 0; pointer-events: none; }
  .tl { display: flex; justify-content: space-between; gap: .4rem; font-size: .74rem; color: var(--text-2); font-weight: 600; }
  .tl .g { color: var(--muted); font-weight: 500; white-space: nowrap; }
  .tl .g.neg { color: var(--c-s2); }
  .sp { height: 54px; }
  .big { position: absolute; inset: 0; opacity: 0; pointer-events: none; transition: opacity .4s .25s; }
  .big.show { opacity: 1; pointer-events: auto; }
  .ck { display: inline-flex; gap: .45rem; align-items: center; font-size: .84rem; }
  .side { font-size: .82rem; }
  .note { color: var(--text-2); margin: .3rem 0 0; }
  .warn { color: var(--danger); }
  .ld { list-style: none; padding: 0; margin: .3rem 0 0; }
  .ld li { display: flex; justify-content: space-between; padding: .18rem 0; border-bottom: 1px solid var(--border); color: var(--text-2); }
  .ld b { font-variant-numeric: tabular-nums; color: var(--text); }
  .ld b.neg { color: var(--c-s2); }
  .load { color: var(--muted); }
  @media (prefers-reduced-motion: reduce) { .tile, .big { transition: none; } }
</style>
