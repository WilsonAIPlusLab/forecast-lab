<script lang="ts">
  // Signature explorable 2: a SHAP waterfall for any month, from last month's sales to the forecast.
  // Data: precomputed natively in R by src/labs/ch12/make_data.R (same model as Lab 13.3).
  import Explorable from '../Explorable.svelte';
  import data from './shap_data.json';
  import './viz';

  type M = { date: string; lag1: number; actual?: number | null; growth?: number | null; pred: number; forecast: number; base: number; shap: number[]; x: (number | null)[]; next_month?: boolean };
  const months = data.months as M[];
  const F: string[] = data.features;
  const NAMES: Record<string, string> = {
    month: 'Calendar month', growth_ly: 'Same month last year’s growth', growth_lm: 'Last month’s growth',
    yoy_lm: 'Last month’s 12-month growth', weekend: 'Weekend days', sent_lm: 'Consumer sentiment', unrate_lm: 'Unemployment rate',
  };
  const MON = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  const iDec = months.findIndex((m) => m.date === '2025-12-01');
  const iNext = months.length - 1;
  let idx = $state(iDec);
  let animate = $state(true);
  let focus: string | null = $state(null);
  const reduce = typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;

  const parse = (s: string) => { const [y, m] = s.split('-').map(Number); return { y, m }; };
  const label = (s: string) => { const { y, m } = parse(s); return `${MON[m - 1]} ${y}`; };
  const short = (s: string) => { const { y, m } = parse(s); return `${MON[m - 1].slice(0, 3)} ${y}`; };
  const money = (v: number) => `${v < 0 ? '−' : '+'}$${Math.abs(v).toFixed(1)}bn`;

  const cur = $derived(months[idx]);
  const bars = $derived.by(() => {
    const m = cur, k = m.lag1 / 100;
    const items = [{ key: 'base', label: 'Base value (an average month)', v: m.base * k },
      ...F.map((f, j) => ({ key: f, label: NAMES[f], v: m.shap[j] * k })).sort((a, b) => Math.abs(b.v) - Math.abs(a.v))];
    let c = 0;
    const rows = items.map((it) => { const r = { ...it, a: c, b: c + it.v }; c += it.v; return r; });
    return { rows, total: c };
  });
  const scale = $derived.by(() => {
    const ends = bars.rows.flatMap((r) => [r.a, r.b]).concat([0, bars.total], cur.actual != null ? [cur.actual - cur.lag1] : []);
    let lo = Math.min(...ends), hi = Math.max(...ends);
    const pad = (hi - lo) * 0.08 || 5; lo -= pad; hi += pad;
    const step = (hi - lo) > 120 ? 40 : (hi - lo) > 60 ? 20 : (hi - lo) > 25 ? 10 : 5;
    const ticks: number[] = []; for (let t = Math.ceil(lo / step) * step; t <= hi; t += step) ticks.push(t);
    return { lo, hi, ticks, p: (v: number) => ((v - lo) / (hi - lo)) * 100 };
  });

  function explain(key: string, m: M, v: number, top: string): string {
    const j = F.indexOf(key), x = j >= 0 ? m.x[j] : null;
    const { y, m: mo } = parse(m.date);
    const prev = MON[(mo + 10) % 12];
    const dir = v >= 0 ? 'adds' : 'subtracts';
    const amt = `<b>${money(v)}</b>`;
    switch (key) {
      case 'base': return `Every forecast starts from the <b>base value</b>: the model's average prediction, ${m.base.toFixed(2)}% growth. On last month's $${m.lag1.toFixed(1)}bn that is worth ${amt}.`;
      case 'month': return `It is ${MON[mo - 1]}. In the training data, ${MON[mo - 1]} tends to grow ${v >= 0 ? 'faster' : 'slower'} than the average month, so the calendar ${dir} ${amt}. This overlaps with the next feature: both carry the seasonal pattern.`;
      case 'growth_ly': return `A year ago, ${MON[mo - 1]} sales grew <b>${(x as number).toFixed(1)}%</b> over ${prev}. Seasonal jumps repeat, so this ${dir} ${amt}${top === key ? ': the biggest single push this month' : ''}.`;
      case 'growth_lm': return `Last month (${prev}), sales grew <b>${(x as number).toFixed(1)}%</b> over the month before. That recent move ${dir} ${amt}.`;
      case 'yoy_lm': return `Last month's sales were <b>${(x as number).toFixed(1)}%</b> above the same month a year earlier. That momentum ${dir} ${amt}.`;
      case 'weekend': return `${MON[mo - 1]} ${y} has <b>${x}</b> Saturdays and Sundays. The model learned a link between the weekday mix and growth, which ${dir} ${amt}. That is a pattern, not proof of cause.`;
      case 'sent_lm': return `Consumer sentiment last month was <b>${x ?? 'missing'}</b>. The model barely uses it: ${amt}.`;
      case 'unrate_lm': return x === null
        ? `The unemployment rate for October 2025 was <b>never published</b> (federal shutdown). XGBoost sends a missing value down a default branch it learned in training: ${amt}.`
        : `Unemployment last month was <b>${x}%</b>. Once seasonality is known, it hardly moves next month's sales: ${amt}.`;
    }
    return '';
  }
  const topKey = $derived(bars.rows.filter((r) => r.key !== 'base').sort((a, b) => Math.abs(b.v) - Math.abs(a.v))[0].key);
  const shown = $derived(focus ?? topKey);
  const shownRow = $derived(bars.rows.find((r) => r.key === shown)!);
  const err = $derived(cur.actual != null ? cur.actual - cur.forecast : null);
  function pick(i: number) { animate = !reduce; idx = i; }
</script>

<Explorable title="Every forecast is last month's sales plus an average month plus one push per feature" caption={`Pick a month. Bars start at <b>last month's sales</b> (the zero line) and add up, feature by feature, to the forecast. Red pushes up, blue pulls down. Hover or tab to a bar for a plain-English reading. Out-of-sample months Jan 2023 to Sep 2026 use the model trained through 2022; October 2026 uses the same model refit through September 2026. Data: FRED RSXFSN (NSA), UMCSENT, UNRATE; $ billions.`}>
  {#snippet controls()}
    <label class="sl">Month <input type="range" min="0" max={iNext} value={idx} oninput={(e) => { animate = false; idx = +(e.target as HTMLInputElement).value; }} aria-label="Forecast month" aria-valuetext={label(cur.date)} /> <b>{short(cur.date)}</b></label>
    <span class="seg" role="group" aria-label="Jump to a month">
      <button class:on={idx === iDec} aria-pressed={idx === iDec} onclick={() => pick(iDec)}>December 2025</button>
      <button class:on={idx === iNext} aria-pressed={idx === iNext} onclick={() => pick(iNext)}>Next month (Oct 2026)</button>
    </span>
  {/snippet}
  {#snippet aside()}
    <div class="side" aria-live="polite">
      <div class="eyebrow">{label(cur.date)}{cur.next_month ? ': not yet happened' : ''}</div>
      <div class="big"><span>${cur.forecast.toFixed(1)}bn</span><small>forecast</small></div>
      {#if cur.actual != null}
        <p class="act">Actual: <b>${cur.actual.toFixed(1)}bn</b>, a miss of <b>{money(err as number)}</b> ({(100 * Math.abs(err as number) / cur.actual).toFixed(1)}%).</p>
      {:else}<p class="act">Actual: not published yet.</p>{/if}
      <div class="why">
        <div class="why-h">{shownRow.label} <b class:up={shownRow.v >= 0} class:down={shownRow.v < 0}>{money(shownRow.v)}</b></div>
        <p>{@html explain(shown, cur, shownRow.v, topKey)}</p>
      </div>
    </div>
  {/snippet}
  <div class="wf" role="group" aria-label={`Waterfall for ${label(cur.date)}: from $${cur.lag1.toFixed(1)}bn last month to a forecast of $${cur.forecast.toFixed(1)}bn`}>
    <div class="row head" aria-hidden="true">
      <div class="lbl">Last month's sales: <b>${cur.lag1.toFixed(1)}bn</b></div>
      <div class="track">{#each scale.ticks as t}<span class="tick" style={`left:${scale.p(t)}%`}>{t === 0 ? '0' : (t > 0 ? '+' : '−') + Math.abs(t)}</span>{/each}</div>
      <div class="val"></div>
    </div>
    {#each bars.rows as r (r.key)}
      <div class="row" class:sel={shown === r.key} role="button" tabindex="0" aria-pressed={shown === r.key}
        onmouseenter={() => (focus = r.key)} onfocus={() => (focus = r.key)} onmouseleave={() => (focus = null)}
        aria-label={`${r.label}: ${money(r.v)}`}>
        <div class="lbl">{r.label}</div>
        <div class="track">
          {#each scale.ticks as t}<span class="grid" class:zero={t === 0} style={`left:${scale.p(t)}%`}></span>{/each}
          <span class="bar" class:up={r.v >= 0} class:down={r.v < 0} class:anim={animate}
            style={`transform: translateX(${scale.p(Math.min(r.a, r.b))}%) scaleX(${Math.max(0.002, Math.abs(r.v) / (scale.hi - scale.lo))})`}></span>
          <span class="end" class:anim={animate} style={`transform: translateX(${scale.p(r.b)}%)`}></span>
        </div>
        <div class="val" class:up={r.v >= 0} class:down={r.v < 0}>{money(r.v)}</div>
      </div>
    {/each}
    <div class="row total" role="note" aria-label={`Forecast: ${money(bars.total)} from last month, $${cur.forecast.toFixed(1)}bn`}>
      <div class="lbl"><b>Forecast: ${cur.forecast.toFixed(1)}bn</b></div>
      <div class="track">
        {#each scale.ticks as t}<span class="grid" class:zero={t === 0} style={`left:${scale.p(t)}%`}></span>{/each}
        <span class="bar fc" class:anim={animate} style={`transform: translateX(${scale.p(Math.min(0, bars.total))}%) scaleX(${Math.max(0.002, Math.abs(bars.total) / (scale.hi - scale.lo))})`}></span>
        {#if cur.actual != null}<span class="actual" class:anim={animate} style={`transform: translateX(${scale.p(cur.actual - cur.lag1)}%)`} title="Actual"><i>actual</i></span>{/if}
      </div>
      <div class="val"><b>{money(bars.total)}</b></div>
    </div>
    <div class="axis-note">Change from last month's sales, $ billions. Zero = last month's level.</div>
  </div>
</Explorable>

<style>
  .wf { font-size: .84rem; }
  .row { display: grid; grid-template-columns: minmax(150px, 220px) 1fr 70px; align-items: center; gap: .6rem; min-height: 34px; border-radius: 6px; padding: 0 .3rem; }
  .row[tabindex]:focus-visible { outline: 2px solid var(--accent-2); }
  .row.sel { background: var(--surface-2); }
  .row.head { min-height: 26px; color: var(--muted); }
  .lbl { color: var(--text-2); line-height: 1.25; }
  .lbl b { color: var(--text); font-variant-numeric: tabular-nums; }
  .track { position: relative; height: 20px; }
  .head .track { height: 16px; }
  .tick { position: absolute; top: 0; transform: translateX(-50%); font-size: 12px; font-variant-numeric: tabular-nums; color: var(--muted); }
  .grid { position: absolute; top: -8px; bottom: -8px; width: 1px; background: color-mix(in srgb, var(--text) 9%, transparent); }
  .grid.zero { background: var(--border-strong); width: 1.5px; }
  .bar { position: absolute; left: 0; top: 2px; height: 16px; width: 100%; transform-origin: 0 50%; border-radius: 3px; }
  .bar.up { background: var(--c-s2); }
  .bar.down { background: var(--c-s1); }
  .bar.fc { background: var(--c-forecast); top: 0; height: 20px; }
  .end { position: absolute; left: 0; top: 18px; height: 22px; width: 100%; border-left: 1px dashed var(--border-strong); pointer-events: none; }
  .actual { position: absolute; left: 0; top: -5px; height: 30px; width: 100%; border-left: 3px solid var(--c-actual); pointer-events: none; }
  .actual i { position: absolute; top: -14px; left: -14px; font-style: normal; font-size: 12px; color: var(--c-actual); }
  .anim { transition: transform 420ms cubic-bezier(0.2, 0, 0, 1); }
  .val { font-variant-numeric: tabular-nums; text-align: right; font-weight: 600; }
  .val.up, b.up { color: var(--c-s2); } .val.down, b.down { color: var(--c-s1); }
  .total { border-top: 1px solid var(--border); margin-top: .3rem; padding-top: .45rem; padding-bottom: .2rem; }
  .axis-note { color: var(--muted); font-size: .78rem; margin: .5rem .3rem 0; }
  .side { font-size: .85rem; color: var(--text-2); }
  .eyebrow { font-size: .8rem; font-weight: 650; color: var(--muted); }
  .big { display: flex; align-items: baseline; gap: .45rem; margin: .2rem 0 .3rem; }
  .big span { font: 650 1.6rem/1.1 var(--font-ui); font-variant-numeric: tabular-nums; color: var(--c-forecast); }
  .big small { color: var(--muted); }
  .act { margin: 0 0 .8rem; }
  .act b { color: var(--text); font-variant-numeric: tabular-nums; }
  .why { border-top: 1px solid var(--border); padding-top: .6rem; }
  .why-h { font-weight: 650; color: var(--text); margin-bottom: .3rem; }
  .why p { margin: 0; line-height: 1.5; }
  .why :global(b) { color: var(--text); }
  @media (max-width: 640px) { .row { grid-template-columns: 110px 1fr 58px; gap: .4rem; } .lbl { font-size: .76rem; } }
  @media (prefers-reduced-motion: reduce) { .anim { transition: none; } }
</style>
