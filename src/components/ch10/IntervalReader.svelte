<script lang="ts">
  import { onMount } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, futureDates } from '../../lib/ts';
  import { C, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { fitETS, forecast, sdH, qnorm } from './models';

  // "Read the band out loud": a real 24-month forecast of retail sales with 50/80/95% bands.
  // Pick a month and a level; the panel writes the sentence you would say to a manager,
  // and the lower chart shows how the band's half-width grows with the horizon.
  const H = 24;
  const LEVELS = [50, 80, 95];
  let el: HTMLDivElement, el2: HTMLDivElement;
  let h = $state(12);
  let level = $state(80);
  let base: { hist: { date: Date; value: number }[]; dates: Date[]; mu: number[]; sd: number[] } | null = $state.raw(null);

  async function load() {
    // post-pandemic history only, like the newsvendor lab: 2022 to the latest month
    const s = await loadSeries('RSXFSN', { start: '2022-01-01' });
    const fit = fitETS(s.data.map((p) => Math.log(p.value)), { m: 12, trend: true, season: true });
    base = {
      hist: s.data.map((p) => ({ date: p.date, value: p.value / 1000 })),
      dates: futureDates(s.data[s.data.length - 1].date, H, 12),
      mu: forecast(fit, H),
      sd: sdH(fit, H),
    };
  }
  // band in $ billions for horizon index k (0-based) at a given level; computed in logs, then exp()
  const band = (k: number, lev: number) => {
    const z = qnorm(1 - (1 - lev / 100) / 2), m = base!.mu[k], s = base!.sd[k];
    return { mid: Math.exp(m) / 1000, lo: Math.exp(m - z * s) / 1000, hi: Math.exp(m + z * s) / 1000 };
  };
  const monthName = (d: Date) => d.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
  const read = $derived.by(() => {
    if (!base) return null;
    const k = h - 1, b = band(k, level), b1 = band(0, level);
    const out = (100 - level) / 2;                    // % of months expected below (and above) the band
    const inN = level === 50 ? '1 out of 2' : level === 80 ? '8 out of 10' : '19 out of 20';   // frequency words
    return { date: base.dates[k], ...b, out, inN, pm: (100 * (b.hi - b.lo)) / 2 / b.mid, ratio: (b.hi - b.lo) / (b1.hi - b1.lo), b80: band(k, 80), b95: band(k, 95) };
  });

  function draw() {
    if (!el || !base || !read) return;
    const W = el.clientWidth;
    const last = base.hist[base.hist.length - 1];
    const rows = base.dates.map((d, k) => ({ date: d, ...band(k, level), o80: band(k, 80), o95: band(k, 95) }));
    const anchor = { date: last.date, mid: last.value, lo: last.value, hi: last.value };
    const area = (lev: number) => [anchor, ...base!.dates.map((d, k) => ({ date: d, ...band(k, lev) }))];
    const sel = rows[h - 1];
    const marks: any[] = [
      // all three bands as context, the chosen level drawn darker
      ...LEVELS.slice().reverse().map((lev) => Plot.areaY(area(lev), { x: 'date', y1: 'lo', y2: 'hi', fill: C.forecast, fillOpacity: lev === level ? 0.34 : 0.1 })),
      Plot.lineY(base.hist.slice(-36), { x: 'date', y: 'value', stroke: C.history, strokeWidth: 2 }),
      Plot.lineY([anchor, ...rows], { x: 'date', y: 'mid', stroke: C.forecast, strokeWidth: 2.4 }),
      Plot.ruleX([sel.date], { stroke: C.text2, strokeDasharray: '3,3' }),
      Plot.link([sel], { x1: 'date', x2: 'date', y1: 'lo', y2: 'hi', stroke: C.forecast, strokeWidth: 3.5 }),
      Plot.dot([sel], { x: 'date', y: 'mid', r: 5, fill: C.forecast, stroke: C.surface, strokeWidth: 1.5 }),
      Plot.text([sel], { x: 'date', y: 'hi', text: (r: any) => `$${r.hi.toFixed(0)} bn`, dy: -9, dx: h > 18 ? -6 : 6, textAnchor: h > 18 ? 'end' : 'start', fill: C.text, fontSize: 12, fontWeight: 600, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
      Plot.text([sel], { x: 'date', y: 'lo', text: (r: any) => `$${r.lo.toFixed(0)} bn`, dy: 11, dx: h > 18 ? -6 : 6, textAnchor: h > 18 ? 'end' : 'start', fill: C.text, fontSize: 12, fontWeight: 600, stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }),
      Plot.text([rows[H - 1]], { x: 'date', y: 'hi', text: () => `${level}%`, dx: 6, textAnchor: 'start', fill: C.text2, fontSize: 12, fontWeight: 600 }),
      Plot.tip(rows, Plot.pointerX({ x: 'date', y: 'mid', title: (r: any) => `${monthName(r.date)}\nPoint forecast: $${r.mid.toFixed(0)} bn\n80% band: $${r.o80.lo.toFixed(0)}–${r.o80.hi.toFixed(0)} bn\n95% band: $${r.o95.lo.toFixed(0)}–${r.o95.hi.toFixed(0)} bn` })),
    ];
    el.replaceChildren(Plot.plot({
      width: W, height: Math.max(270, Math.min(360, W * 0.45)), marginLeft: 48, marginRight: 40, marginTop: 20, style: plotStyle(),
      x: { label: null }, y: { grid: true, label: '↑ Monthly retail sales ($ billions)' },
      marks,
    }));
    // half-width of the band, as ± % of the point forecast, by horizon
    const hw = LEVELS.flatMap((lev) => base!.dates.map((_, k) => { const b = band(k, lev); return { h: k + 1, v: (100 * (b.hi - b.lo)) / 2 / b.mid, lev: `${lev}%` }; }));
    el2.replaceChildren(Plot.plot({
      width: W, height: 190, marginLeft: 48, marginRight: 44, marginTop: 14, marginBottom: 36, style: plotStyle(),
      x: { label: 'Months ahead →', domain: [1, H], ticks: [1, 6, 12, 18, 24] }, y: { grid: true, label: '↑ Band half-width (± % of forecast)', zero: true },
      marks: [
        Plot.lineY(hw, { x: 'h', y: 'v', z: 'lev', stroke: C.forecast, strokeOpacity: (d: any) => (d.lev === `${level}%` ? 1 : 0.35), strokeWidth: (d: any) => (d.lev === `${level}%` ? 2.6 : 1.4) }),
        Plot.text(hw.filter((d) => d.h === H), { x: 'h', y: 'v', text: 'lev', dx: 6, textAnchor: 'start', fill: C.text2, fontSize: 12 }),
        Plot.ruleX([h], { stroke: C.text2, strokeDasharray: '3,3' }),
        Plot.dot(hw.filter((d) => d.h === h && d.lev === `${level}%`), { x: 'h', y: 'v', r: 5, fill: C.forecast, stroke: C.surface, strokeWidth: 1.5 }),
        Plot.tip(hw.filter((d) => d.lev === `${level}%`), Plot.pointerX({ x: 'h', y: 'v', title: (d: any) => `${d.h} month${d.h > 1 ? 's' : ''} ahead\n${d.lev} band: ±${d.v.toFixed(1)}% of the forecast` })),
      ],
    }));
  }

  $effect(() => { base; h; level; draw(); });
  onMount(() => { load(); return watchLayout(el, draw); });
  const usd = (v: number) => `$${v.toFixed(0)} billion`;
</script>

<Explorable title="Read the band out loud: what an interval tells a manager"
  caption="A 24-month forecast of U.S. retail sales excluding food services (RSXFSN, NSA, $ billions per month) from additive exponential smoothing on log sales (trend + seasonality), fitted to January 2022 onward. Bands are computed in logs and transformed back. Drag the month and pick a level: the panel writes the sentence you would say to a manager. The lower chart shows how the band's half-width grows with the horizon, for all three levels.">
  {#snippet controls()}
    <label class="sl">Month ahead <input type="range" min="1" max={H} step="1" bind:value={h} aria-valuetext={`${h} months ahead`} /> <b>{h}</b></label>
    <div class="seg" role="group" aria-label="Interval level">
      {#each LEVELS as l}<button class:on={level === l} aria-pressed={level === l} onclick={() => (level = l)}>{l}%</button>{/each}
    </div>
  {/snippet}
  {#snippet aside()}
    {#if read}
      <div class="ro" aria-live="polite">
        <p class="say">“Our best guess for <b>{monthName(read.date)}</b> is about <b>{usd(read.mid)}</b>. We expect sales between <b>{usd(read.lo)}</b> and <b>{usd(read.hi)}</b>: a band like this catches the truth about <b>{read.inN}</b> times. Expect a number below it about {read.out}% of the time, and above it about {read.out}% of the time.”</p>
        <div class="stat"><span class="stat-v">±{read.pm.toFixed(1)}%</span><span class="stat-l">band half-width, as a share of the forecast</span></div>
        <p>This {level}% band is <b>{read.ratio.toFixed(1)}×</b> as wide as the {level}% band one month ahead.</p>
        <p>Same month, other levels: 80% is ${read.b80.lo.toFixed(0)}–{read.b80.hi.toFixed(0)} billion; 95% is ${read.b95.lo.toFixed(0)}–{read.b95.hi.toFixed(0)} billion. The 95% band is always about <b>1.5×</b> as wide as the 80% band.</p>
      </div>
    {/if}
  {/snippet}
  <div bind:this={el} role="img" aria-label="Retail sales history and a 24-month forecast with 50, 80 and 95 percent bands; the chosen month's band is marked"></div>
  <div bind:this={el2} role="img" aria-label="Band half-width as a percent of the forecast, rising with the number of months ahead, for 50, 80 and 95 percent bands"></div>
</Explorable>

<style>
  .ro { font-size: .86rem; color: var(--text-2); display: grid; gap: .6rem; }
  .ro p { margin: 0; }
  .ro b { color: var(--text); font-variant-numeric: tabular-nums; }
  .say { border-left: 3px solid var(--ch, var(--accent)); padding-left: .65rem; color: var(--text); line-height: 1.5; }
</style>
