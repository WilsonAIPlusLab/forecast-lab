<script lang="ts">
  // Prepare the panel before PCA: transform each series to growth rates, then standardize.
  // Toggle each step off and watch what the "first factor" turns into.
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { PANEL, loadPanel, loadLevelPanel, loadRecessions, pca } from './lib';

  let transform: 'growth' | 'level' = $state('growth');
  let standardize = $state(true);
  let G: Awaited<ReturnType<typeof loadPanel>> | null = $state(null);
  let L: Awaited<ReturnType<typeof loadLevelPanel>> | null = $state(null);
  let rec: { a: Date; b: Date }[] = [];
  let elW: HTMLDivElement, elF: HTMLDivElement;

  onMount(() => {
    Promise.all([loadPanel(), loadLevelPanel(), loadRecessions()]).then(([g, l, r]) => { rec = r; L = l; G = g; });
    return watchLayout(elW, () => { drawW(); drawF(); });
  });

  const res = $derived.by(() => {
    const D = transform === 'growth' ? G : L;
    if (!D) return null;
    const P = pca(D.X, 4, standardize); // clip at ±4 SD, exactly as in the factor lab
    let w = P.vectors[0];
    if (w[0] < 0) w = w.map((v) => -v); // payrolls load positively: "up" = stronger economy
    const f = P.Z.map((r) => r.reduce((s, v, j) => s + v * w[j], 0));
    const fs = transform === 'growth' ? f.map((_, i) => (i < 2 ? NaN : (f[i] + f[i - 1] + f[i - 2]) / 3)) : f;
    const load = PANEL.map((p, j) => ({ label: p.label, w: w[j], sq: w[j] ** 2 })).sort((a, b) => b.w - a.w);
    const top3 = load.slice().sort((a, b) => b.sq - a.sq).slice(0, 3);
    const pay = w[0];
    return { share: P.share, load, top3, top3sq: top3.reduce((s, x) => s + x.sq, 0), f: fs, dates: D.dates, pay };
  });

  const verdict = $derived.by(() => {
    if (transform === 'growth' && standardize) return { ok: true, t: 'Ready. Every series counts in standard-deviation units, and the factor rises and falls with the business cycle.' };
    if (transform === 'growth') return { ok: false, t: 'The noisiest series win. Initial claims, housing starts and clothing sales swing the most in their own units, so they grab the weight. Payrolls, the best single measure of the economy, get almost none.' };
    if (standardize) return { ok: false, t: 'The factor is mostly a time trend. Anything that grows over the years looks “correlated” with everything else that grows. Most of that big % explained is the shared upward drift, not booms and busts.' };
    return { ok: false, t: 'Both problems at once: trends in levels, and units deciding the weights.' };
  });

  function drawW() {
    if (!res || !elW) return;
    const W = elW.clientWidth, narrow = W < 520;
    if (W < 200) return; // not laid out yet; watchLayout redraws once it has a real width
    const d = res.load;
    const ext = Math.max(0.6, ...d.map((r) => Math.abs(r.w)));
    const ch = Plot.plot({
      width: W, height: d.length * 17 + 56, marginLeft: narrow ? 118 : 140, marginRight: 40, marginTop: 8, marginBottom: 44, style: plotStyle(),
      x: { domain: [-ext * 1.3, ext * 1.3], grid: true, label: 'Loading (weight) on component 1 →', labelAnchor: 'center' },
      y: { domain: d.map((r) => r.label), label: null, tickSize: 0 },
      marks: [
        Plot.barX(d, { y: 'label', x: 'w', fill: (r: any) => (r.w >= 0 ? C.fitted : C.s[1]), fillOpacity: 0.85, rx: 2 }),
        Plot.ruleX([0], { stroke: C.borderStrong }),
        Plot.text(d.filter((r) => r.w > -0.005), { y: 'label', x: 'w', text: (r: any) => (r.w < 0.005 ? '' : '+') + Math.abs(r.w).toFixed(2), dx: 4, textAnchor: 'start', fill: C.text2, fontSize: 12 }),
        Plot.text(d.filter((r) => r.w <= -0.005), { y: 'label', x: 'w', text: (r: any) => '−' + Math.abs(r.w).toFixed(2), dx: -4, textAnchor: 'end', fill: C.text2, fontSize: 12 }),
      ],
    });
    ch.setAttribute('aria-label', `Loadings of the 20 indicators on the first principal component, ${transform === 'growth' ? 'growth rates' : 'log levels'}, ${standardize ? 'standardized' : 'in raw units'}. Largest: ${res.top3.map((t) => `${t.label} ${t.w.toFixed(2)}`).join(', ')}.`);
    elW.replaceChildren(ch);
  }
  function drawF() {
    if (!res || !elF) return;
    const W = elF.clientWidth;
    if (W < 200) return;
    const rows = res.dates.map((d, i) => ({ d, v: res.f[i] })).filter((r) => Number.isFinite(r.v));
    const ch = Plot.plot({
      width: W, height: 190, marginLeft: 44, marginRight: 12, marginTop: 14, style: plotStyle(),
      x: { label: null }, y: { grid: true, label: transform === 'growth' ? '↑ factor, 3-month average' : '↑ factor score' },
      marks: [
        Plot.rectX(rec.filter((r) => +r.b >= +res!.dates[0]), { x1: 'a', x2: 'b', fill: C.muted, fillOpacity: 0.16 }),
        Plot.ruleY([0], { stroke: C.borderStrong }),
        Plot.lineY(rows, { x: 'd', y: 'v', stroke: C.fitted, strokeWidth: 2.25 }),
        Plot.tip(rows, Plot.pointerX({ x: 'd', y: 'v', title: (r: any) => `${r.d.toLocaleDateString('en-US', { month: 'short', year: 'numeric' })}\nFactor: ${r.v.toFixed(2)}` })),
      ],
    });
    ch.setAttribute('aria-label', transform === 'growth' ? 'The first factor through time; it drops in each grey recession.' : 'The first factor through time; it climbs steadily like a time trend.');
    elF.replaceChildren(ch);
  }
  $effect(() => { res; drawW(); drawF(); });
  const pct = (v: number) => (100 * v).toFixed(0) + '%';
</script>

<Explorable title="Prepare the panel before PCA: transform, then standardize" caption={`The same 20 indicators as the wall above, January 1993 to September 2026. Bars show each series' weight (loading) in the first principal component; teal = rises with the factor, rose = falls with it. The small chart shows the factor through time with NBER recessions in grey. Switch to <b>Log levels</b> or turn off <b>Standardize</b> to see what goes wrong. Values beyond ±4 SD are clipped, as in the lab. Data: FRED, 20 series.`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Transformation">
      <button class:on={transform === 'growth'} aria-pressed={transform === 'growth'} onclick={() => (transform = 'growth')}>Growth rates</button>
      <button class:on={transform === 'level'} aria-pressed={transform === 'level'} onclick={() => (transform = 'level')}>Log levels</button>
    </div>
    <label class="ck"><input type="checkbox" bind:checked={standardize} /> Standardize (z-scores)</label>
  {/snippet}
  {#snippet aside()}
    {#if res}
      <div class="side" aria-live="polite">
        <div class="kp"><span class="v">{pct(res.share[0])}</span><span class="l">of the panel's variance explained by component 1{standardize ? `: as much as ${(20 * res.share[0]).toFixed(1)} of the 20 series would carry on their own` : ' (in raw units, so big-unit series count more)'}</span></div>
        <div class="kp"><span class="v">{pct(res.top3sq)}</span><span class="l">of the factor's weight sits on just 3 series: {res.top3.map((t) => t.label).join(', ')}</span></div>
        <div class="kp"><span class="v">{res.pay >= 0 ? '+' : '−'}{Math.abs(res.pay).toFixed(2)}</span><span class="l">loading of payroll jobs</span></div>
        <div class="verdict" class:ok={verdict.ok}><b>{verdict.ok ? '✓ ' : '✗ '}</b>{verdict.t}</div>
      </div>
    {/if}
  {/snippet}
  <div bind:this={elW} class="chart"></div>
  <div bind:this={elF} class="chart2"></div>
  {#if !res}<p class="load">Loading 20 series…</p>{/if}
</Explorable>

<style>
  .chart { min-height: 380px; }
  .chart2 { min-height: 190px; margin-top: .5rem; }
  .ck { display: inline-flex; gap: .45rem; align-items: center; font-size: .84rem; }
  .side { font-size: .82rem; }
  .kp { display: flex; flex-direction: column; margin: .45rem 0; }
  .kp .v { font: 700 1.35rem/1.1 var(--font-ui); color: var(--text); font-variant-numeric: tabular-nums; }
  .kp .l { color: var(--muted); font-size: .76rem; }
  .verdict { margin-top: .6rem; border: 1px solid var(--border); border-radius: 8px; padding: .5rem .6rem; background: var(--bg-2); color: var(--text-2); }
  .verdict b { color: var(--danger); }
  .verdict.ok b { color: var(--good); }
  .load { color: var(--muted); }
</style>
