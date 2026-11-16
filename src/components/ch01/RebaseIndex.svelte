<script lang="ts">
  // Rebase: U.S. vs Iowa payroll jobs. In levels, Iowa is a flat line at the bottom (units problem).
  // As an index, both start at 100 in the base year, and the base year decides which line looks
  // "ahead" at the end. Yet the growth rate between any two dates never changes with the base.
  // A third view, Iowa's share of U.S. jobs, shows a ratio (the same idea as per-capita).
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { monthLabel, mkey, avg, signed } from './util';

  type View = 'level' | 'index' | 'share';
  interface Row { date: Date; us: number; ia: number }
  let rows: Row[] = $state([]);
  let view: View = $state('index');
  let base = $state(2019);
  let el: HTMLDivElement;
  const FIXED_FROM = '2000-01';   // a fixed comparison span, to show what rebasing cannot change

  onMount(() => {
    // PAYEMS: U.S. nonfarm payrolls; IANA: Iowa nonfarm payrolls; both thousands of jobs, SA, monthly
    Promise.all([loadSeries('PAYEMS', { start: '1990-01-01' }), loadSeries('IANA', { start: '1990-01-01' })]).then(([u, i]) => {
      const im = new Map(i.data.map((p) => [mkey(p.date), p.value]));
      rows = u.data.filter((p) => im.has(mkey(p.date))).map((p) => ({ date: p.date, us: p.value, ia: im.get(mkey(p.date))! }));
    });
    return watchLayout(el, draw);
  });

  const bUS = $derived(avg(rows.filter((r) => r.date.getFullYear() === base).map((r) => r.us)));
  const bIA = $derived(avg(rows.filter((r) => r.date.getFullYear() === base).map((r) => r.ia)));
  const last = $derived(rows[rows.length - 1]);
  const idxUS = $derived(last ? (100 * last.us) / bUS : NaN);
  const idxIA = $derived(last ? (100 * last.ia) / bIA : NaN);
  const fixed = $derived(rows.find((r) => mkey(r.date) === FIXED_FROM));
  const gUS = $derived(last && fixed ? 100 * (last.us / fixed.us - 1) : NaN);  // growth Jan 2000 -> latest: same under any base
  const gIA = $derived(last && fixed ? 100 * (last.ia / fixed.ia - 1) : NaN);
  const share0 = $derived(rows.length ? (100 * rows[0].ia) / rows[0].us : NaN);
  const share1 = $derived(last ? (100 * last.ia) / last.us : NaN);

  function draw() {
    if (!el || !rows.length || !last) return;
    const W = Math.max(280, el.clientWidth || 600);   // floor guards against a transient zero-width layout
    const H = Math.max(280, Math.min(380, W * 0.5));
    let marks: any[] = [];
    let y: any = { grid: true, nice: true };
    if (view === 'level') {
      y = { ...y, label: 'jobs (millions)', tickFormat: (v: number) => (v / 1000).toLocaleString('en-US'), domain: [0, 170000] };
      marks = [
        Plot.lineY(rows, { x: 'date', y: 'us', stroke: C.s[0], strokeWidth: 2.2 }),
        Plot.lineY(rows, { x: 'date', y: 'ia', stroke: C.s[1], strokeWidth: 2.2 }),
        Plot.text([last], { x: 'date', y: 'us', text: () => `U.S. ${(last.us / 1000).toFixed(1)}M`, dy: -12, textAnchor: 'end', fill: C.s[0], fontSize: 13, fontWeight: 650 }),
        Plot.text([last], { x: 'date', y: 'ia', text: () => `Iowa ${(last.ia / 1000).toFixed(2)}M`, dy: -12, textAnchor: 'end', fill: C.s[1], fontSize: 13, fontWeight: 650 }),
        Plot.tip(rows, Plot.pointerX({ x: 'date', y: 'us', title: (r: Row) => `${monthLabel(r.date)}\nU.S.: ${(r.us / 1000).toFixed(1)} million jobs\nIowa: ${(r.ia / 1000).toFixed(3)} million jobs` })),
      ];
    } else if (view === 'index') {
      const d = rows.map((r) => ({ date: r.date, us: (100 * r.us) / bUS, ia: (100 * r.ia) / bIA }));
      y = { ...y, label: `index, ${base} average = 100` };
      marks = [
        Plot.rectX([0], { x1: () => new Date(base, 0, 1), x2: () => new Date(base + 1, 0, 1), fill: C.actual, fillOpacity: 0.16 }),
        Plot.ruleY([100], { stroke: C.text2, strokeWidth: 1.5, strokeOpacity: 0.8 }),
        Plot.text([0], { x: () => new Date(base, 6, 1), frameAnchor: 'top', text: () => `base ${base}`, dy: -2, textAnchor: base > 2015 ? 'end' : 'start', dx: base > 2015 ? -6 : 6, fill: C.text2, fontSize: 12, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
        Plot.lineY(d, { x: 'date', y: 'us', stroke: C.s[0], strokeWidth: 2.2 }),
        Plot.lineY(d, { x: 'date', y: 'ia', stroke: C.s[1], strokeWidth: 2.2 }),
        Plot.text([d[d.length - 1]], { x: 'date', y: 'us', text: (r: any) => `U.S. ${r.us.toFixed(1)}`, dx: 6, dy: r0(d) ? -9 : 9, textAnchor: 'start', fill: C.s[0], fontSize: 13, fontWeight: 650 }),
        Plot.text([d[d.length - 1]], { x: 'date', y: 'ia', text: (r: any) => `Iowa ${r.ia.toFixed(1)}`, dx: 6, dy: r0(d) ? 9 : -9, textAnchor: 'start', fill: C.s[1], fontSize: 13, fontWeight: 650 }),
        Plot.tip(d, Plot.pointerX({ x: 'date', y: 'us', title: (r: any) => `${monthLabel(r.date)}\nU.S.: ${r.us.toFixed(1)}\nIowa: ${r.ia.toFixed(1)}\n(index, ${base} average = 100)` })),
      ];
    } else {
      const d = rows.map((r) => ({ date: r.date, s: (100 * r.ia) / r.us }));
      y = { ...y, label: 'Iowa jobs as % of U.S. jobs', tickFormat: (v: number) => `${v.toFixed(2)}%` };
      marks = [
        Plot.lineY(d, { x: 'date', y: 's', stroke: C.s[1], strokeWidth: 2.4 }),
        Plot.dot([d[0], d[d.length - 1]], { x: 'date', y: 's', r: 4.5, fill: C.s[1] }),
        Plot.text([d[0]], { x: 'date', y: 's', text: (r: any) => `${r.s.toFixed(2)}%`, dy: -12, textAnchor: 'start', fill: C.text, fontSize: 13, fontWeight: 650 }),
        Plot.text([d[d.length - 1]], { x: 'date', y: 's', text: (r: any) => `${r.s.toFixed(2)}%`, dy: -12, textAnchor: 'end', fill: C.text, fontSize: 13, fontWeight: 650 }),
        Plot.tip(d, Plot.pointerX({ x: 'date', y: 's', title: (r: any) => `${monthLabel(r.date)}\nIowa share of U.S. jobs: ${r.s.toFixed(3)}%` })),
      ];
    }
    const chart = Plot.plot({ width: W, height: H, marginLeft: 54, marginRight: view === 'index' ? 82 : 16, marginTop: 18, style: plotStyle(), x: { label: null }, y, marks });
    chart.setAttribute('role', 'img');
    chart.setAttribute('aria-label', view === 'level' ? `U.S. and Iowa payroll jobs in millions since 1990. Iowa's line is nearly flat at the bottom because it is about 1% of the U.S. total.`
      : view === 'index' ? `U.S. and Iowa payroll jobs indexed to the ${base} average = 100. Latest: U.S. ${idxUS.toFixed(1)}, Iowa ${idxIA.toFixed(1)}.`
      : `Iowa's share of U.S. payroll jobs, from ${share0.toFixed(2)}% in ${monthLabel(rows[0].date)} to ${share1.toFixed(2)}% in ${monthLabel(last.date)}.`);
    el.replaceChildren(chart);
  }
  // which end label sits on top (avoid overlap)
  const r0 = (d: { us: number; ia: number }[]) => d[d.length - 1].us >= d[d.length - 1].ia;

  $effect(() => { rows; view; base; draw(); });
</script>

<Explorable title="The base year decides who looks ahead; it never changes a growth rate" caption={`U.S. and Iowa payroll jobs (thousands, seasonally adjusted). <b>Levels</b>: Iowa is about 1% of the U.S., so its line hugs the floor. <b>Index</b>: both lines equal 100 in the base year; drag the base year and watch the end gap change while the growth since January 2000 stays put. <b>Iowa’s share</b> divides one by the other, the same idea as a per-capita number. Data: FRED (PAYEMS, IANA).`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="View">
      <button class:on={view === 'level'} aria-pressed={view === 'level'} onclick={() => (view = 'level')}>Levels</button>
      <button class:on={view === 'index'} aria-pressed={view === 'index'} onclick={() => (view = 'index')}>Index</button>
      <button class:on={view === 'share'} aria-pressed={view === 'share'} onclick={() => (view = 'share')}>Iowa’s share</button>
    </div>
    <label class="sl" class:dim={view !== 'index'}>Base year
      <input type="range" min="1990" max="2025" step="1" bind:value={base} disabled={view !== 'index'} aria-label="Base year of the index" aria-valuetext={`${base}`} />
      <b>{base}</b>
    </label>
  {/snippet}
  {#snippet aside()}
    <div class="board" aria-live="polite">
      {#if last}
        {#if view === 'index'}
          <div class="pair">
            <div class="stat"><span class="stat-v us">{idxUS.toFixed(1)}</span><span class="stat-l">U.S., {monthLabel(last.date)}</span></div>
            <div class="stat"><span class="stat-v ia">{idxIA.toFixed(1)}</span><span class="stat-l">Iowa, {monthLabel(last.date)}</span></div>
          </div>
          <p class="what">Read each as “percent of its {base} level”: since {base}, U.S. jobs have changed by {signed(idxUS - 100)}% and Iowa jobs by {signed(idxIA - 100)}%. The gap at the end is <b>{Math.abs(idxUS - idxIA).toFixed(1)}</b> index points and depends on the base year.</p>
          <p class="fixed"><b>What never changes:</b> from January 2000 to {monthLabel(last.date)}, U.S. jobs grew {signed(gUS)}% and Iowa jobs {signed(gIA)}%, whatever base you pick.</p>
        {:else if view === 'level'}
          <div class="stat"><span class="stat-v">{(100 * last.ia / last.us).toFixed(1)}%</span><span class="stat-l">Iowa jobs as a share of U.S. jobs</span></div>
          <p class="what">On one axis in thousands, Iowa’s ups and downs are invisible: the U.S. line sets the scale. Different sizes call for an index, a growth rate or a ratio.</p>
        {:else}
          <div class="stat"><span class="stat-v ia">{share0.toFixed(2)}% → {share1.toFixed(2)}%</span><span class="stat-l">Iowa’s share of U.S. jobs, {monthLabel(rows[0].date)} to {monthLabel(last.date)}</span></div>
          <p class="what">Iowa added jobs, but more slowly than the country, so its share shrank. A ratio like this answers “relative to the whole, is it gaining or losing?”, exactly like dividing by population to get a per-capita number.</p>
        {/if}
      {/if}
    </div>
  {/snippet}
  <div bind:this={el} class="chart"></div>
</Explorable>

<style>
  .chart { min-height: 280px; }
  .board { font-size: .86rem; line-height: 1.55; display: grid; gap: .7rem; }
  .pair { display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; }
  .us { color: var(--c-s1); }
  .ia { color: var(--c-s2); }
  .what, .fixed { margin: 0; color: var(--text-2); }
  .fixed { padding: .5rem .6rem; border-left: 3px solid var(--c-actual); background: var(--bg-2); border-radius: 4px; }
  .dim { opacity: .5; }
</style>
