<script lang="ts">
  // Granger detective: who helps predict whom? Every arrow is a pairwise Granger F-test in a
  // two-variable VAR (vars::causality), precomputed in build_data.R for two samples and three lag lengths.
  import Explorable from '../Explorable.svelte';
  import { D, META, col, type VarKey } from './varlib';

  const NODES: VarKey[] = ['ffr', 'spread', 'infl', 'unemp'];
  const P: Record<string, [number, number]> = { ffr: [112, 78], spread: [368, 78], infl: [112, 262], unemp: [368, 262] };
  const R = 42;
  let sample = $state('1960-2000');
  let lag = $state('4');
  let focus: VarKey | null = $state(null);
  const tests = $derived(D.granger[sample][lag]);
  const strength = (p: number) => Math.min(9, Math.max(1.4, -Math.log10(Math.max(p, 1e-9)) * 1.35));
  const verdict = (p: number) => (p < 0.01 ? 'strong' : p < 0.05 ? 'yes' : p < 0.1 ? 'weak' : 'no');
  const fmtP = (p: number) => (p < 0.0001 ? '< 0.0001' : p.toFixed(p < 0.01 ? 4 : 3));
  const name = (k: VarKey) => META[k].label.toLowerCase().replace('fed funds rate', 'the funds rate').replace('term spread', 'the term spread');

  function geom(a: VarKey, b: VarKey) {
    const [x1, y1] = P[a], [x2, y2] = P[b];
    const dx = x2 - x1, dy = y2 - y1, L = Math.hypot(dx, dy), ux = dx / L, uy = dy / L;
    const nx = -uy, ny = ux, bend = 20;
    const sx = x1 + ux * R + nx * 8, sy = y1 + uy * R + ny * 8, ex = x2 - ux * (R + 7) + nx * 8, ey = y2 - uy * (R + 7) + ny * 8;
    const cx = (x1 + x2) / 2 + nx * bend, cy = (y1 + y2) / 2 + ny * bend;
    return { d: `M${sx},${sy} Q${cx},${cy} ${ex},${ey}`, lx: (sx + 2 * cx + ex) / 4 + nx * 10, ly: (sy + 2 * cy + ey) / 4 + ny * 10 };
  }
  const shown = $derived(tests.filter((t) => t.p < 0.1));
  const sorted = $derived([...tests].filter((t) => !focus || t.from === focus || t.to === focus).sort((a, b) => a.p - b.p));
  const nSig = $derived(tests.filter((t) => t.p < 0.05).length);
</script>

<Explorable title="Who helps predict whom? Many links fade after 1985"
  caption={`Each arrow X → Y means: adding past values of X to a two-variable VAR significantly improves forecasts of Y (Granger F-test). Thicker arrows = smaller p-values; dashed = only significant at 10%; no arrow = no evidence. Click a variable to see only its tests. Quarterly data: CPI inflation, unemployment, federal funds rate and the 10-year minus 3-month Treasury spread (FRED: CPIAUCSL, UNRATE, FEDFUNDS, GS10, TB3MS).`}>
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Sample period">
      {#each [['1960-2000', '1960–2000'], ['1985-2019', '1985–2019']] as [k, l]}<button class:on={sample === k} onclick={() => (sample = k)}>{l}</button>{/each}
    </div>
    <div class="seg" role="group" aria-label="Lags in each VAR">
      {#each ['2', '4', '8'] as k}<button class:on={lag === k} onclick={() => (lag = k)}>{k} lags</button>{/each}
    </div>
  {/snippet}
  {#snippet aside()}
    <div class="tab">
      <div class="lbl">{focus ? `Tests involving ${name(focus)}` : 'All 12 tests'}, sorted by p-value</div>
      <table>
        <thead><tr><th>Test</th><th>F</th><th>p</th><th>Predicts?</th></tr></thead>
        <tbody>
          {#each sorted as t}
            <tr class={verdict(t.p)}>
              <td><span style:color={col(t.from)}>{META[t.from].short}</span> → <span style:color={col(t.to)}>{META[t.to].short}</span></td>
              <td>{t.F.toFixed(2)}</td><td>{fmtP(t.p)}</td><td>{verdict(t.p)}</td>
            </tr>
          {/each}
        </tbody>
      </table>
      <p class="sum" aria-live="polite"><b>{nSig} of 12</b> links significant at 5% in {sample.replace('-', '–')} with {lag} lags.</p>
    </div>
  {/snippet}
  <svg viewBox="0 0 480 340" class="g" role="img" aria-label={`Directed graph of Granger causality, ${sample}, ${lag} lags: ${shown.map((t) => `${META[t.from].label} to ${META[t.to].label}, p ${fmtP(t.p)}`).join('; ')}`}>
    <defs>
      {#each NODES as k}
        <marker id={`gd-ah-${k}`} viewBox="0 0 10 10" refX="6" refY="5" markerWidth="4.2" markerHeight="4.2" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill={col(k)} /></marker>
      {/each}
    </defs>
    {#each shown as t (t.from + t.to)}
      {@const g = geom(t.from, t.to)}
      {@const dim = focus && t.from !== focus && t.to !== focus}
      <path d={g.d} fill="none" stroke={col(t.from)} stroke-width={strength(t.p)} stroke-dasharray={t.p >= 0.05 ? '5 4' : null}
        marker-end={`url(#gd-ah-${t.from})`} class="arr" style:opacity={dim ? 0.08 : t.p < 0.05 ? 0.9 : 0.55}>
        <title>{META[t.from].label} → {META[t.to].label}: F = {t.F.toFixed(2)}, p = {fmtP(t.p)}</title>
      </path>
      {#if !dim && focus}
        <text x={g.lx} y={g.ly} class="pl" text-anchor="middle">p {fmtP(t.p)}</text>
      {/if}
    {/each}
    {#each NODES as k}
      {@const [x, y] = P[k]}
      <g class="node" role="button" tabindex="0" aria-pressed={focus === k} aria-label={`Show only tests involving ${META[k].label}`}
        onclick={() => (focus = focus === k ? null : k)} onkeydown={(e) => (e.key === 'Enter' || e.key === ' ') && (e.preventDefault(), (focus = focus === k ? null : k))}>
        <circle cx={x} cy={y} r={R} fill="var(--surface-2)" stroke={col(k)} stroke-width={focus === k ? 3.5 : 2} />
        <text {x} y={y + 5} text-anchor="middle" class="nl" fill={col(k)}>{META[k].short}</text>
      </g>
    {/each}
  </svg>
</Explorable>

<style>
  .g { width: 100%; height: auto; max-height: 380px; display: block; }
  .arr { transition: opacity .35s cubic-bezier(.2, 0, 0, 1); }
  .node { cursor: pointer; outline: none; }
  .node:focus-visible circle { stroke-width: 4; stroke-dasharray: 3 3; }
  .nl { font: 700 13px var(--font-ui); pointer-events: none; }
  .pl { font: 600 12px var(--font-ui); fill: var(--text-2); paint-order: stroke; stroke: var(--surface); stroke-width: 3px; font-variant-numeric: tabular-nums; }
  .tab { font-size: .78rem; }
  .lbl { font-size: .75rem; color: var(--muted); font-weight: 650; margin-bottom: .3rem; }
  table { width: 100%; margin: 0 0 .5rem; font-size: .76rem; }
  th, td { padding: .22rem .3rem; text-align: right; font-variant-numeric: tabular-nums; }
  th:first-child, td:first-child { text-align: left; }
  tr.no td, tr.weak td { color: var(--muted); }
  tr.strong td:last-child, tr.yes td:last-child { color: var(--good); font-weight: 650; }
  .sum { color: var(--text-2); margin: 0; }
  @media (prefers-reduced-motion: reduce) { .arr { transition: none; } }
</style>
