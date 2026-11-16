<script lang="ts">
  // Explorable: read an AICc table and translate a fitted ETS model into plain words.
  // Every number comes from R's ets() (src/labs/ch05/make_data.R): all 15 default candidates, same split as the labs.
  import Explorable from '../Explorable.svelte';
  import data from './etsdata.json';

  const SETS = data.ladder as any[];
  let si = $state(0);
  const L = $derived(SETS[si]);
  const rows = $derived.by(() => {
    const best = Math.min(...L.rows.map((r: any) => r.aicc));
    return [...L.rows].map((r: any) => ({ ...r, d: r.aicc - best })).sort((a: any, b: any) => a.d - b.d);
  });
  const maxD = $derived(Math.max(...rows.map((r: any) => r.d)));
  let pick = $state('');                                    // selected model code; '' = the best
  $effect(() => { si; pick = ''; });
  const cur = $derived(rows.find((r: any) => r.code === pick) ?? rows[0]);

  const band = (d: number) => (d < 2 ? { k: 'tie', t: 'tie with best' } : d <= 10 ? { k: 'weak', t: 'less support' } : { k: 'out', t: 'ruled out' });
  const barW = (d: number) => (maxD > 0 ? 4 + 96 * (Math.log10(1 + d) / Math.log10(1 + maxD)) : 4);   // log scale, so small gaps stay visible
  const f2 = (v: number) => (v >= 0.995 ? v.toFixed(4) : v < 0.001 ? v.toFixed(4) : v.toFixed(3));
  const bn = (v: number) => `$${(v / 1000).toFixed(1)} billion`;

  const decode = (m: string) => {
    const [e, t, s] = m.replace('ETS(', '').replace(')', '').split(',');
    return [
      `<b>${e}</b> error: ${e === 'M' ? 'surprises are a percentage of sales' : 'surprises are a fixed size, in dollars'}`,
      `<b>${t}</b> trend: ${t === 'N' ? 'no slope' : t === 'Ad' ? 'a slope that fades out (damped)' : 'a straight-line slope that never fades'}`,
      `<b>${s}</b> season: ${s === 'N' ? 'no seasonal pattern' : s === 'M' ? 'each month is a percentage above or below the level' : 'each month is a fixed dollar amount above or below the level'}`,
    ];
  };
  const words = $derived.by(() => {
    const r = cur, out: string[] = [];
    const a = r.alpha;
    if (a >= 0.95) out.push(`<b>α = ${f2(a)}</b>: the level jumps to each new month, just like the naive forecast; the model keeps almost no memory. When the window holds a collapse like April 2020, this is often the model chasing that outlier.`);
    else if (a < 0.02) out.push(`<b>α = ${f2(a)}</b>: the level barely moves. The model treats month-to-month changes as noise and keeps a nearly fixed path.`);
    else { const half = Math.max(1, Math.ceil(Math.log(0.5) / Math.log(1 - a))); out.push(`<b>α = ${f2(a)}</b>: the level's information is on average about ${(1 / a).toFixed(1)} months old; the last ${half === 1 ? 'month holds' : half + ' months hold'} half of its weight.`); }
    if (r.beta != null) {
      if (r.beta < 0.001) out.push(`<b>β = ${f2(r.beta)}</b>: the slope is essentially fixed: the same growth per month throughout the sample.`);
      else { const bs = r.beta / a; out.push(`<b>β = ${f2(r.beta)}</b>: the slope learns ${bs > 0.3 ? 'quickly' : 'slowly'}; only ${(100 * bs).toFixed(0)}% of each level surprise (β/α) feeds into it, so it reflects roughly the last ${Math.round(1 / bs)} months of growth.`); }
    }
    if (r.gamma != null) {
      const cap = 1 - a;
      if (r.gamma < 0.001) out.push(`<b>γ = ${f2(r.gamma)}</b>: the seasonal pattern is frozen. Every December gets the same ${cur.method.endsWith('M)') ? 'percentage' : 'dollar'} boost, year after year.`);
      else if (r.gamma / cap > 0.6) out.push(`<b>γ = ${f2(r.gamma)}</b>, close to its ceiling of 1 − α = ${cap.toFixed(2)}: each month's seasonal index is rebuilt mostly from the same month last year, so the pattern can drift from year to year.`);
      else out.push(`<b>γ = ${f2(r.gamma)}</b>: the seasonal pattern updates gradually, one year's evidence at a time (the ceiling is 1 − α = ${cap.toFixed(2)}).`);
    }
    if (r.phi != null) out.push(`<b>φ = ${r.phi.toFixed(3)}</b>: the slope shrinks by ${(100 * (1 - r.phi)).toFixed(1)}% a month. In total the forecast adds about ${Math.round(r.phi / (1 - r.phi))} months' worth of today's slope, then levels off.`);
    out.push(cur.method.startsWith('ETS(M') ? `<b>σ = ${r.sigma.toFixed(3)}</b>: a typical one-step miss is about ${(100 * r.sigma).toFixed(1)}% of sales.` : `<b>σ = ${Math.round(r.sigma).toLocaleString('en-US')}</b>: a typical one-step miss is about ${bn(r.sigma)}.`);
    return out;
  });
  const verdict = $derived(cur.d < 1e-9 ? `Lowest AICc: this is the model <code>ets()</code> picks.` : cur.d < 2 ? `ΔAICc = ${cur.d.toFixed(1)}: within 2 points of the best, a statistical tie. Either model is defensible.` : cur.d <= 10 ? `ΔAICc = ${cur.d.toFixed(1)}: less support than the best, but not ruled out.` : `ΔAICc = ${cur.d.toFixed(1)}: more than 10 points behind, so the data give it essentially no support next to the best.`);
</script>

<Explorable title="Read the AICc table, then translate the model into words" caption={`Every default ETS candidate fitted by R's <code>ets()</code> to data through August 2025 (U.S. Census Bureau via FRED, $ millions, not seasonally adjusted). <b>ΔAICc</b> is each model's AICc minus the best one; bars use a log scale so small gaps stay visible. Rules of thumb: under 2 is a tie, 2 to 10 is weaker support, over 10 is ruled out. Pick a model to read it. You can compare AICc only within one data set: "Clothing, from 2015" and "from 2021" use different data, so their AICc values cannot be compared with each other. The test-year MAE (the 12 months to August 2026) is shown for curiosity: AICc never sees it.`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Data set">
      {#each SETS as x, i}<button class:on={si === i} onclick={() => (si = i)}>{x.label}</button>{/each}
    </div>
  {/snippet}
  {#snippet aside()}
    <div class="ro" aria-live="polite">
      <div class="lbl">{cur.method}</div>
      <ul class="dec">{#each decode(cur.method) as d}<li>{@html d}</li>{/each}</ul>
      <p class="vd">{@html verdict}</p>
      <ul class="tr">{#each words as w}<li>{@html w}</li>{/each}</ul>
      <p class="mae">{cur.k} estimated quantities. Test-year MAE: <b>{bn(cur.mae)}</b> a month.</p>
    </div>
  {/snippet}
  <div class="note">{L.note}. {L.n} months; <code>ets()</code> picks <b>{L.auto}</b>.</div>
  <ol class="lad" aria-label="Candidate models sorted by AICc, best first">
    {#each rows as r (r.code)}
      {@const b = band(r.d)}
      <li>
        <button class="row" class:on={cur.code === r.code} aria-pressed={cur.code === r.code} onclick={() => (pick = r.code)}>
          <span class="m">{r.method}</span>
          <span class="track"><span class="bar {b.k}" style={`width:${barW(r.d)}%`}></span></span>
          <span class="dv">{r.d < 1e-9 ? 'best' : '+' + r.d.toFixed(1)}</span>
          <span class="bt {b.k}">{r.d < 1e-9 ? '' : b.t}</span>
        </button>
      </li>
    {/each}
  </ol>
</Explorable>

<style>
  .note { font-size: .8rem; color: var(--muted); margin-bottom: .5rem; line-height: 1.45; }
  .lad { list-style: none; margin: 0; padding: 0; display: grid; gap: 2px; }
  .lad li { margin: 0; }
  .row { all: unset; box-sizing: border-box; width: 100%; cursor: pointer; display: grid; grid-template-columns: 7.2rem minmax(0, 1fr) 3.4rem 6.6rem; gap: .6rem; align-items: center; padding: .22rem .45rem; border-radius: 6px; font-size: .8rem; }
  .row:hover { background: var(--bg-2); }
  .row.on { background: color-mix(in srgb, var(--ch, var(--accent)) 14%, var(--surface)); outline: 1px solid color-mix(in srgb, var(--ch, var(--accent)) 45%, var(--border)); }
  .row:focus-visible { outline: 2px solid var(--accent-2); }
  .m { font-family: var(--font-mono); color: var(--text); white-space: nowrap; }
  .track { height: 10px; background: var(--bg-2); border-radius: 5px; overflow: hidden; }
  .bar { display: block; height: 100%; border-radius: 5px; }
  .bar.tie { background: var(--good); }
  .bar.weak { background: var(--warm); }
  .bar.out { background: var(--muted); opacity: .55; }
  .dv { font-family: var(--font-mono); text-align: right; color: var(--text-2); font-variant-numeric: tabular-nums; }
  .bt { font-size: .74rem; color: var(--muted); white-space: nowrap; }
  .bt.tie { color: var(--good); font-weight: 650; }
  @media (max-width: 520px) { .row { grid-template-columns: 6.4rem minmax(0, 1fr) 3rem; } .bt { display: none; } }
  .ro { display: grid; gap: .55rem; font-size: .82rem; line-height: 1.5; }
  .lbl { font: 700 1.2rem var(--font-mono); color: var(--text); }
  .dec, .tr { margin: 0; padding-left: 1rem; color: var(--text-2); display: grid; gap: .3rem; }
  .vd { margin: 0; color: var(--text); }
  .mae { margin: 0; color: var(--muted); font-size: .78rem; }
</style>
