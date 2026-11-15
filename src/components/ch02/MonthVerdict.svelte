<script lang="ts">
  // "Was this month good or bad?" Four ways to read one month of NSA retail sales.
  import { onMount } from 'svelte';
  import Explorable from '../Explorable.svelte';
  import { loadSeries } from '../../lib/ts';

  type Row = { date: Date; nsa: number; sa: number | null };
  let rows: Row[] = $state([]);
  let i = $state(0);
  let minI = $state(0);

  onMount(async () => {
    const [r, a, f] = await Promise.all([loadSeries('RSXFSN'), loadSeries('RSAFS'), loadSeries('RSFSDP')]);
    const k = (d: Date) => `${d.getFullYear()}-${d.getMonth()}`;
    const fm = new Map(f.data.map((p) => [k(p.date), p.value]));
    const am = new Map(a.data.map((p) => [k(p.date), p.value]));
    rows = r.data.map((p) => ({ date: p.date, nsa: p.value, sa: am.has(k(p.date)) && fm.has(k(p.date)) ? am.get(k(p.date))! - fm.get(k(p.date))! : null }));
    minI = rows.findIndex((x) => x.date.getFullYear() === 2015);
    const dec = rows.map((x, j) => (x.date.getMonth() === 11 ? j : -1)).filter((j) => j >= 0);
    i = dec[dec.length - 1];
  });

  const pc = (a: number, b: number) => 100 * (a / b - 1);
  const median = (v: number[]) => { const s = v.slice().sort((x, y) => x - y); const n = s.length; return n % 2 ? s[(n - 1) / 2] : (s[n / 2 - 1] + s[n / 2]) / 2; };
  const v = $derived.by(() => {
    if (!rows.length || i < 13) return null;
    const r = rows[i], p = rows[i - 1], y = rows[i - 12];
    const mom = pc(r.nsa, p.nsa);
    // seasonal norm: the median Nov->Dec style change for this calendar month over the previous five years
    const past = [1, 2, 3, 4, 5].map((k) => i - 12 * k).filter((j) => j >= 1).map((j) => pc(rows[j].nsa, rows[j - 1].nsa));
    const norm = median(past);
    const sa = r.sa != null && p.sa != null ? pc(r.sa, p.sa) : NaN;
    return { r, mom, norm, gap: mom - norm, yoy: pc(r.nsa, y.nsa), sa };
  });
  const label = (d: Date) => d.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
  const prevLabel = (d: Date) => new Date(d.getFullYear(), d.getMonth() - 1, 1).toLocaleDateString('en-US', { month: 'long' });
  const f1 = (x: number) => (Number.isFinite(x) ? (x > 0 ? '+' : x < 0 ? '−' : '') + Math.abs(x).toFixed(1) + '%' : 'n/a');
  const tiles = $derived(v ? [
    { k: 'Raw change vs last month', val: v.mom, note: `NSA, ${label(v.r.date)} vs ${prevLabel(v.r.date)}. Mostly calendar.`, mislead: true },
    { k: 'Versus the seasonal norm', val: v.gap, note: `Raw change minus the typical ${f1(v.norm)} for this month (median of the previous five years).` },
    { k: 'Versus the same month last year', val: v.yoy, note: 'NSA year-over-year. Seasonality cancels, but so does all of last year’s news.' },
    { k: 'Seasonally adjusted vs last month', val: v.sa, note: 'Census X-13 adjusted (RSAFS − RSFSDP). The number economists quote.' },
  ] : []);
  const maxAbs = $derived(Math.max(4, ...tiles.map((t) => (Number.isFinite(t.val) ? Math.abs(t.val) : 0))));
</script>

<Explorable title="Was it a good month? Depends how you ask" caption="Pick any month since 2015. The first bar is what a careless headline would report. The other three each remove the calendar in a different way. Data: U.S. retail sales excl. food services (RSXFSN, NSA) and the Census seasonally adjusted equivalent (RSAFS − RSFSDP), $ millions, via FRED.">
  {#snippet controls()}
    {#if rows.length}
      <label class="sl">Month <input type="range" min={minI} max={rows.length - 1} bind:value={i} aria-label="Month to evaluate" aria-valuetext={label(rows[i].date)} /> <b class="wide">{label(rows[i].date)}</b></label>
    {/if}
  {/snippet}
  {#if v}
    <div class="bars" role="list">
      {#each tiles as t}
        <div class="row" role="listitem" class:mis={t.mislead}>
          <div class="k">{t.k}</div>
          <div class="track" aria-hidden="true">
            <span class="zero"></span>
            {#if Number.isFinite(t.val)}<span class="bar" class:neg={t.val < 0} style:width={`${(Math.abs(t.val) / maxAbs) * 50}%`}></span>{/if}
          </div>
          <div class="val">{f1(t.val)}</div>
          <div class="note">{t.note}</div>
        </div>
      {/each}
    </div>
  {:else}
    <div class="loading">Loading…</div>
  {/if}
</Explorable>

<style>
  .bars { display: grid; gap: .9rem; }
  .row { display: grid; grid-template-columns: minmax(150px, 220px) minmax(0, 1fr) 4.5rem; gap: .25rem .9rem; align-items: center; }
  .k { font-weight: 650; color: var(--text); font-size: .9rem; }
  .row.mis .k { color: var(--muted); }
  .track { position: relative; height: 18px; }
  .zero { position: absolute; left: 50%; top: -3px; bottom: -3px; width: 1.5px; background: var(--border-strong); }
  .bar { position: absolute; left: 50%; top: 2px; height: 14px; border-radius: 0 4px 4px 0; background: var(--good); }
  .bar.neg { left: auto; right: 50%; border-radius: 4px 0 0 4px; background: var(--danger); }
  .row.mis .bar { background: var(--surface-3); border: 1px dashed var(--border-strong); }
  .val { font: 650 1rem var(--font-ui); font-variant-numeric: tabular-nums; text-align: right; color: var(--text); }
  .note { grid-column: 1 / -1; font-size: .8rem; color: var(--muted); margin-top: -.15rem; }
  .wide { min-width: 9.5rem !important; font-family: var(--font-ui) !important; }
  .loading { color: var(--muted); padding: 1rem 0; }
  @media (max-width: 600px) { .row { grid-template-columns: 1fr 4rem; } .track { grid-column: 1 / -1; grid-row: 2; } }
  @media (prefers-reduced-motion: reduce) { .bar { transition: none; } }
</style>
