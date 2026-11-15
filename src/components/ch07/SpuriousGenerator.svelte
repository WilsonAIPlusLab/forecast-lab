<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { rng } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import './viz';

  // Spurious regression generator: two independent random walks, OLS fitted live, a running tally of |t| > 2.
  const N = 100;
  const R = rng(1974);
  let diffMode = $state(false);
  let pair: { x: number[]; y: number[] } = $state({ x: [], y: [] });
  let tLev: number[] = $state([]);
  let tDif: number[] = $state([]);
  let elTs: HTMLDivElement, elSc: HTMLDivElement, elH: HTMLDivElement;

  const walk = () => { let s = 0; return Array.from({ length: N }, () => (s += R.norm())); };
  const d1 = (v: number[]) => v.slice(1).map((x, i) => x - v[i]);
  function fit(x: number[], y: number[]) {
    const n = x.length, mx = x.reduce((a, b) => a + b, 0) / n, my = y.reduce((a, b) => a + b, 0) / n;
    let sxy = 0, sxx = 0, syy = 0;
    for (let i = 0; i < n; i++) { sxy += (x[i] - mx) * (y[i] - my); sxx += (x[i] - mx) ** 2; syy += (y[i] - my) ** 2; }
    const r = sxy / Math.sqrt(sxx * syy), b = sxy / sxx;
    return { a: my - b * mx, b, r2: r * r, t: r * Math.sqrt((n - 2) / (1 - r * r)) };
  }
  function simulate(times: number) {
    const L = tLev.slice(), D = tDif.slice();
    let last = pair;
    for (let i = 0; i < times; i++) {
      const x = walk(), y = walk();
      L.push(fit(x, y).t); D.push(fit(d1(x), d1(y)).t);
      last = { x, y };
    }
    tLev = L; tDif = D; pair = last;
  }
  function reset() { tLev = []; tDif = []; simulate(1); }

  const shown = $derived(diffMode ? { x: d1(pair.x), y: d1(pair.y) } : pair);
  const f = $derived(shown.x.length ? fit(shown.x, shown.y) : null);
  const tally = $derived(diffMode ? tDif : tLev);
  const share = $derived(tally.length ? tally.filter((t) => Math.abs(t) > 2).length / tally.length : 0);

  function draw() {
    if (!elTs || !f) return;
    const cx = C.s[0], cy = C.s[1];
    const ts = shown.x.flatMap((v, i) => [{ t: i + 1, v, s: 'x' }, { t: i + 1, v: shown.y[i], s: 'y' }]);
    elTs.replaceChildren(Plot.plot({
      width: elTs.clientWidth, height: 220, marginLeft: 36, marginRight: 22, style: plotStyle(),
      x: { label: 'time →' }, y: { grid: true, label: null },
      marks: [
        Plot.ruleY([0], { stroke: C.borderStrong }),
        Plot.lineY(ts, { x: 't', y: 'v', z: 's', stroke: (d: any) => (d.s === 'x' ? cx : cy), strokeWidth: diffMode ? 1.4 : 2.2 }),
        Plot.text(ts, Plot.selectLast({ x: 't', y: 'v', z: 's', text: 's', dx: 6, textAnchor: 'start', fill: (d: any) => (d.s === 'x' ? cx : cy), fontWeight: 700, fontSize: 13 })),
      ],
    }));
    const pts = shown.x.map((x, i) => ({ x, y: shown.y[i] }));
    const xs = [Math.min(...shown.x), Math.max(...shown.x)];
    const sig = Math.abs(f.t) > 2;
    elSc.replaceChildren(Plot.plot({
      width: elSc.clientWidth, height: 220, marginLeft: 36, style: plotStyle(),
      x: { label: 'x →', grid: true }, y: { label: '↑ y', grid: true },
      marks: [
        Plot.dot(pts, { x: 'x', y: 'y', fill: C.muted, fillOpacity: 0.55, r: 2.6 }),
        Plot.line(xs.map((x) => ({ x, y: f.a + f.b * x })), { x: 'x', y: 'y', stroke: sig ? C.danger : C.good, strokeWidth: 3 }),
      ],
    }));
    const lim = 20;
    const hv = tally.map((t) => Math.max(-lim, Math.min(lim, t)));
    elH.replaceChildren(Plot.plot({
      width: elH.clientWidth, height: 170, marginLeft: 36, marginBottom: 34, style: plotStyle(),
      x: { domain: [-lim, lim], label: `t-statistic of the slope (all ${tally.length} regressions; beyond ±${lim} piled at the edge)` }, y: { grid: true, label: null },
      marks: [
        Plot.rectX([0], { x1: -2, x2: 2, fill: C.good, fillOpacity: 0.1 }),
        Plot.rectY(hv, Plot.binX({ y: 'count' }, { x: (d: number) => d, fill: diffMode ? C.s[0] : C.s[1], fillOpacity: 0.8, thresholds: 40, domain: [-lim, lim] } as any)),
        Plot.ruleX([-2, 2], { stroke: C.text2, strokeDasharray: '4 4' }),
        Plot.ruleX([Math.max(-lim, Math.min(lim, f.t))], { stroke: C.text, strokeWidth: 2.5 }),
        Plot.ruleY([0], { stroke: C.borderStrong }),
      ],
    }));
  }

  $effect(() => { shown; f; tally; draw(); });
  onMount(() => { simulate(1); const a = watchLayout(elTs, draw); return a; });
  const pct = (v: number) => `${Math.round(100 * v)}%`;
</script>

<Explorable title="Two unrelated random walks, one 'significant' regression" caption="Each click draws two <b>independent</b> random walks of 100 steps, x and y, and regresses y on x. The fitted line is red when |t| &gt; 2 (the usual cutoff for 'significant' at about 5%) and green otherwise. The histogram keeps every regression you have run; the black line marks the current one. Then tick <b>Difference both</b> to regress the month-to-month changes instead. Simulated data, seeded so everyone sees the same sequence.">
  {#snippet controls()}
    <button class="btn btn-sm" onclick={() => simulate(1)}>New pair</button>
    <button class="btn btn-ghost btn-sm" onclick={() => simulate(100)}>Run 100 more</button>
    <label class="chk"><input type="checkbox" bind:checked={diffMode} /> Difference both</label>
  {/snippet}
  {#snippet aside()}
    {#if f}
      <div class="ro" aria-live="polite">
        <div class="pair">
          <div class="stat"><span class="stat-v" class:bad={Math.abs(f.t) > 2}>{f.t.toFixed(1)}</span><span class="stat-l">t-statistic, this pair</span></div>
          <div class="stat"><span class="stat-v">{f.r2.toFixed(2)}</span><span class="stat-l">R², this pair</span></div>
        </div>
        <div class="tally">
          {#if tally.length >= 10}
            <div class="big" class:bad={share > 0.1}>{pct(share)}</div>
            <div>of <b>{tally.length}</b> regressions {diffMode ? 'in differences' : 'in levels'} had |t| &gt; 2. A valid test should say so about <b>5%</b> of the time.</div>
          {:else}
            <div><b>{tally.filter((t) => Math.abs(t) > 2).length}</b> of <b>{tally.length}</b> {tally.length === 1 ? 'regression' : 'regressions'} so far had |t| &gt; 2. Click <b>New pair</b> a few times, or <b>Run 100 more</b>, to build a tally.</div>
          {/if}
        </div>
        {#if tLev.length >= 50}
          <p class="cmp">Levels: <b>{pct(tLev.filter((t) => Math.abs(t) > 2).length / tLev.length)}</b> · Differences: <b>{pct(tDif.filter((t) => Math.abs(t) > 2).length / tDif.length)}</b></p>
        {/if}
        <button class="btn btn-ghost btn-sm" onclick={reset}>Reset tally</button>
      </div>
    {/if}
  {/snippet}
  <div class="grid">
    <div><div class="lab">{diffMode ? 'Changes in x and y' : 'The two random walks'}</div><div bind:this={elTs} role="img" aria-label="The two simulated series over time"></div></div>
    <div><div class="lab">y against x, with the OLS line</div><div bind:this={elSc} role="img" aria-label="Scatter plot of y against x with the fitted regression line"></div></div>
  </div>
  <div bind:this={elH} class="hist" role="img" aria-label="Histogram of t-statistics from all simulated regressions"></div>
</Explorable>

<style>
  .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
  @media (max-width: 640px) { .grid { grid-template-columns: 1fr; } }
  .lab { font-size: .8rem; color: var(--muted); font-weight: 600; margin-bottom: .2rem; }
  .hist { margin-top: .8rem; }
  .ro { display: flex; flex-direction: column; gap: .8rem; font-size: .84rem; color: var(--text-2); }
  .pair { display: flex; gap: 1.4rem; }
  .bad { color: var(--danger) !important; }
  .tally { display: flex; flex-direction: column; gap: .3rem; padding: .7rem .8rem; background: var(--bg-2); border-radius: 8px; border: 1px solid var(--border); }
  .big { font: 700 2.2rem/1 var(--font-ui); font-variant-numeric: tabular-nums; color: var(--good); }
  .cmp { margin: 0; font-variant-numeric: tabular-nums; }
  .chk { display: inline-flex; align-items: center; gap: .4rem; cursor: pointer; }
  .chk input { accent-color: var(--accent); }
</style>
