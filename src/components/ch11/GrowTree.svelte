<script lang="ts">
  // Chapter 12 · Explorable 2: grow a regression tree by hand on two features (calendar month,
  // last month's growth) of real retail sales growth. Every candidate cut shows its SSE reduction;
  // "Best split" does what rpart does; the leaves slider shows overfitting on the 2023+ test months.
  import { onMount } from 'svelte';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, ym } from '../../lib/ts';
  import { scan, meanOf, sse, type Cut } from './tree';
  import './viz'; // registers the "ch11-tree" chart used by the code labs on this page

  const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const MIN_LEAF = 3, MAXL = 40;
  const YLO = -30, YHI = 28; // g1 axis range, % (COVID months reach about ±27%)

  interface N { id: number; idx: number[]; box: [number, number, number, number]; value: number; sse: number; f?: number; thr?: number; l?: N; r?: N }
  type Row = { date: Date; m: number; g: number; g1: number };

  let train: Row[] = $state.raw([]);
  let test: Row[] = [];
  let X: number[][] = [], y: number[] = [];
  let ready = $state(false);
  let root: N | null = null;
  let version = $state(0);          // bump to re-derive after mutating the (non-reactive) tree
  let selId = $state(1);
  let hover: { f: number; thr: number } | null = $state(null);
  let k = $state(1);                // leaves slider
  let curve: { k: number; tr: number; te: number }[] = $state([]);
  let W = $state(640);
  let gCursor = $state(-1);
  let nextId = 1;

  const mk = (idx: number[], box: N['box']): N => ({ id: nextId++, idx, box, value: meanOf(y, idx), sse: sse(y, idx) });
  function split(n: N, f: number, thr: number) {
    n.f = f; n.thr = thr;
    const [x0, x1, y0, y1] = n.box;
    n.l = mk(n.idx.filter((i) => X[i][f] <= thr), f === 0 ? [x0, thr, y0, y1] : [x0, x1, y0, thr]);
    n.r = mk(n.idx.filter((i) => X[i][f] > thr), f === 0 ? [thr, x1, y0, y1] : [x0, x1, thr, y1]);
  }
  const leavesOf = (n: N): N[] => (n.l && n.r ? [...leavesOf(n.l), ...leavesOf(n.r)] : [n]);
  const predict = (n: N, x: number[]): number => (n.l && n.r ? predict(x[n.f!] <= n.thr! ? n.l : n.r, x) : n.value);
  const rmse = (n: N, rows: Row[]) => Math.sqrt(rows.reduce((s, r) => s + (r.g - predict(n, [r.m, r.g1])) ** 2, 0) / rows.length);
  function bestOf(n: N) {
    let best: (Cut & { f: number }) | null = null;
    for (const f of [0, 1]) for (const c of scan(X, y, n.idx, f, MIN_LEAF)) if (!best || c.gain > best.gain + 1e-9) best = { ...c, f };
    return best;
  }
  /** One step of best-first growth: split the leaf whose best cut reduces SSE the most. */
  function growOnce(t: N) {
    let best: any = null, at: N | null = null;
    for (const lf of leavesOf(t)) { const c = bestOf(lf); if (c && (!best || c.gain > best.gain)) { best = c; at = lf; } }
    if (!best || !at) return null;
    split(at, best.f, best.thr); return at;
  }
  function fresh() { nextId = 1; return mk(train.map((_, i) => i), [0.5, 12.5, YLO, YHI]); }
  function buildK(kk: number) { const t = fresh(); for (let j = 1; j < kk; j++) if (!growOnce(t)) break; return t; }

  onMount(async () => {
    const s = await loadSeries('RSXFSN', { start: '2009-11-01' });
    const d = s.data, rows: Row[] = [];
    for (let t = 2; t < d.length; t++) rows.push({ date: d[t].date, m: d[t].date.getMonth() + 1, g: 100 * Math.log(d[t].value / d[t - 1].value), g1: 100 * Math.log(d[t - 1].value / d[t - 2].value) });
    train = rows.filter((r) => r.date.getFullYear() < 2023); test = rows.filter((r) => r.date.getFullYear() >= 2023);
    X = train.map((r) => [r.m, r.g1]); y = train.map((r) => r.g);
    const t = fresh(), c: typeof curve = [];
    for (let j = 1; j <= MAXL; j++) { c.push({ k: j, tr: rmse(t, train), te: rmse(t, test) }); if (!growOnce(t)) break; }
    curve = c; root = fresh(); ready = true; version++;
  });

  // ── derived state ──
  const leaves = $derived.by(() => { version; return root ? leavesOf(root) : []; });
  const sel = $derived(leaves.find((l) => l.id === selId) ?? leaves.slice().sort((a, b) => b.sse - a.sse)[0]);
  const err = $derived.by(() => { version; return root ? { tr: rmse(root, train), te: rmse(root, test) } : { tr: 0, te: 0 }; });
  const monthCuts = $derived.by(() => {
    if (!sel) return [];
    const ok = new Map(scan(X, y, sel.idx, 0, MIN_LEAF).map((c) => [c.thr, c]));
    return Array.from({ length: 11 }, (_, j) => { const thr = j + 1.5; return { thr, cut: ok.get(thr) ?? null }; });
  });
  const gCuts = $derived(sel ? scan(X, y, sel.idx, 1, MIN_LEAF) : []);
  const gainMax = $derived(Math.max(1e-9, ...monthCuts.map((c) => c.cut?.gain ?? 0), ...gCuts.map((c) => c.gain)));
  const bestHere = $derived.by(() => {
    let b: { f: number; thr: number; gain: number } | null = null;
    for (const c of monthCuts) if (c.cut && (!b || c.cut.gain > b.gain)) b = { f: 0, thr: c.thr, gain: c.cut.gain };
    for (const c of gCuts) if (!b || c.gain > b.gain) b = { f: 1, thr: c.thr, gain: c.gain };
    return b;
  });
  const vmax = $derived(Math.max(1, ...leaves.map((l) => Math.abs(l.value))));

  // ── actions ──
  function doSplit(f: number, thr: number) {
    if (!sel) return;
    split(sel, f, thr); hover = null; gCursor = -1;
    selId = [sel.l!, sel.r!].sort((a, b) => b.sse - a.sse)[0].id;
    k = leaves.length + 1; version++;
  }
  function bestSplit() {
    if (!root) return;
    const at = growOnce(root); if (!at) return;
    selId = [at.l!, at.r!].sort((a, b) => b.sse - a.sse)[0].id;
    k = leavesOf(root).length; version++;
  }
  function setK(v: number) { k = v; root = buildK(v); selId = leavesOf(root).sort((a, b) => b.sse - a.sse)[0].id; hover = null; version++; }
  function reset() { setK(1); }

  // ── geometry ──
  const H = 330, mL = 46, mR = 10, mT = 10, mB = 34;
  const sx = (m: number) => mL + ((m - 0.5) / 12) * (W - mL - mR);
  const sy = (v: number) => mT + ((YHI - Math.max(YLO, Math.min(YHI, v))) / (YHI - YLO)) * (H - mT - mB);
  const rb = (l: N) => ({ x0: sx(l.box[0]), x1: sx(l.box[1]), y0: sy(l.box[3]), y1: sy(l.box[2]) });
  const jit = (i: number) => (((i * 7919) % 13) / 13 - 0.5) * 0.5;
  const col = (v: number) => (v >= 0 ? 'var(--c-s3)' : 'var(--c-s2)');
  const pct = (v: number) => `${v >= 0 ? '+' : '−'}${Math.abs(v).toFixed(1)}%`;
  const share = (g: number) => (sel && sel.sse > 0 ? Math.round((100 * g) / sel.sse) : 0);

  // scan mini-charts
  const sw = $derived(Math.max(240, Math.min(W, 900) / (W > 760 ? 2 : 1) - 24));
  const SH = 92;
  const gx = (v: number) => 8 + ((v - YLO) / (YHI - YLO)) * (sw - 16);
  const gy = (g: number) => SH - 18 - (g / gainMax) * (SH - 30);
  function gKey(e: KeyboardEvent) {
    if (!gCuts.length) return;
    if (e.key === 'ArrowRight' || e.key === 'ArrowUp') { gCursor = Math.min(gCuts.length - 1, gCursor + 1); e.preventDefault(); }
    else if (e.key === 'ArrowLeft' || e.key === 'ArrowDown') { gCursor = Math.max(0, gCursor - 1); e.preventDefault(); }
    else if (e.key === 'Enter' && gCursor >= 0) { doSplit(1, gCuts[gCursor].thr); return; }
    else return;
    hover = { f: 1, thr: gCuts[gCursor].thr };
  }
  function gMove(e: PointerEvent) {
    const r = (e.currentTarget as SVGElement).getBoundingClientRect();
    const v = YLO + ((e.clientX - r.left - 8) / (sw - 16)) * (YHI - YLO);
    let bi = -1, bd = Infinity; gCuts.forEach((c, i) => { const dd = Math.abs(c.thr - v); if (dd < bd) { bd = dd; bi = i; } });
    gCursor = bi; if (bi >= 0) hover = { f: 1, thr: gCuts[bi].thr };
  }

  // error-vs-leaves chart
  const EW = $derived(sw), EH = 150;
  const eMax = $derived(Math.max(1, ...curve.map((c) => Math.max(c.tr, c.te))));
  const ex = (kk: number) => 30 + ((kk - 1) / (MAXL - 1)) * (EW - 44);
  const ey = (v: number) => 10 + (1 - v / eMax) * (EH - 34);
  const path = (key: 'tr' | 'te') => curve.map((c, i) => `${i ? 'L' : 'M'}${ex(c.k).toFixed(1)},${ey(c[key]).toFixed(1)}`).join('');
  const bestTest = $derived(curve.length ? curve.reduce((a, b) => (b.te < a.te ? b : a)) : null);
</script>

<Explorable title="Grow a tree: each split is the cut that removes the most squared error" caption="Each dot is one month of 2010–2022: its position shows the <b>calendar month</b> and <b>last month's growth</b>; its color shows <b>this month's growth</b> (green up, red down). A tree forecasts with the average of its rectangle. Click a rectangle, then click a bar or the curve below to cut it yourself, or press <b>Best split</b> to let the algorithm choose. Drag <b>Leaves</b> to grow a big tree and watch the test error (2023 onward) stop improving. Data: FRED RSXFSN, monthly % change, not seasonally adjusted.">
  {#snippet controls()}
    <button class="btn btn-sm btn-primary" onclick={bestSplit} disabled={!ready}>Best split</button>
    <label class="sl">Leaves <input type="range" min="1" max={MAXL} value={k} oninput={(e) => setK(+e.currentTarget.value)} aria-valuetext={`${k} leaves`} disabled={!ready} /> <b>{k}</b></label>
    <button class="btn btn-sm btn-ghost" onclick={reset} disabled={!ready}>Start over</button>
  {/snippet}
  <div class="gt" bind:clientWidth={W}>
    {#if ready}
      <svg width={W} height={H} role="group" aria-label="Partition of months by calendar month and last month's growth. Each rectangle is a leaf of the tree.">
        {#each [-20, -10, 0, 10, 20] as v}
          <line x1={mL} x2={W - mR} y1={sy(v)} y2={sy(v)} class={v === 0 ? 'zero' : 'grid'} />
          <text x={mL - 6} y={sy(v) + 4} text-anchor="end" class="tick">{v > 0 ? '+' : v < 0 ? '−' : ''}{Math.abs(v)}%</text>
        {/each}
        {#each MON as m, i}<text x={sx(i + 1)} y={H - 14} text-anchor="middle" class="tick">{W < 520 ? m[0] : m}</text>{/each}
        <text x={mL} y={H - 1} class="ax">calendar month →</text>
        <text x={12} y={mT + 4} class="ax" transform={`rotate(-90 12 ${mT + 4})`} text-anchor="end">last month's growth</text>
        {#each leaves as l (l.id)}
          {@const b = rb(l)}
          <rect x={b.x0 + 1} y={b.y0 + 1} width={Math.max(0, b.x1 - b.x0 - 2)} height={Math.max(0, b.y1 - b.y0 - 2)} rx="4"
            fill={col(l.value)} fill-opacity={0.05 + 0.22 * Math.abs(l.value) / vmax}
            class="leaf" class:sel={sel?.id === l.id} role="button" tabindex="0"
            aria-label={`Leaf with ${l.idx.length} months, average growth ${pct(l.value)}${sel?.id === l.id ? ', selected' : ''}`}
            onclick={() => { selId = l.id; hover = null; }} onkeydown={(e) => (e.key === 'Enter' || e.key === ' ') && ((selId = l.id), e.preventDefault())} />
        {/each}
        {#each train as r, i}
          <circle cx={sx(r.m + jit(i))} cy={sy(r.g1)} r="3.3" fill={col(r.g)} fill-opacity={0.35 + 0.65 * Math.min(1, Math.abs(r.g) / 15)} class="pt"><title>{ym(r.date)}: this month {pct(r.g)}, last month {pct(r.g1)}</title></circle>
        {/each}
        {#each leaves as l (l.id)}
          {@const b = rb(l)}
          {#if b.x1 - b.x0 > 44 && b.y1 - b.y0 > 34}
            <text x={(b.x0 + b.x1) / 2} y={(b.y0 + b.y1) / 2} text-anchor="middle" class="lv">{pct(l.value)}</text>
            <text x={(b.x0 + b.x1) / 2} y={(b.y0 + b.y1) / 2 + 15} text-anchor="middle" class="ln">{l.idx.length} mo</text>
          {/if}
        {/each}
        {#if hover && sel}
          {#if hover.f === 0}
            <line x1={sx(hover.thr)} x2={sx(hover.thr)} y1={sy(sel.box[3])} y2={sy(sel.box[2])} class="cand" />
          {:else}
            <line x1={sx(sel.box[0])} x2={sx(sel.box[1])} y1={sy(hover.thr)} y2={sy(hover.thr)} class="cand" />
          {/if}
        {/if}
      </svg>

      <div class="panels">
        <div class="panel">
          <div class="ph">Cut the selected leaf ({sel?.idx.length} months, average {sel ? pct(sel.value) : ''}) on…</div>
          <div class="sub">calendar month: bar height = how much squared error the cut removes</div>
          <svg width={sw} height={SH} role="group" aria-label="Candidate cuts on calendar month">
            <line x1="8" x2={sw - 8} y1={SH - 18} y2={SH - 18} class="zero" />
            {#each monthCuts as c, j}
              {@const bx = 8 + (j + 0.5) * ((sw - 16) / 11)}
              {@const bw = Math.max(6, (sw - 16) / 11 - 6)}
              {#if c.cut}
                {@const isBest = bestHere?.f === 0 && bestHere.thr === c.thr}
                <rect x={bx - bw / 2} y={gy(c.cut.gain)} width={bw} height={SH - 18 - gy(c.cut.gain)} rx="2" class="bar" class:best={isBest}
                  role="button" tabindex="0" aria-label={`Cut between ${MON[j]} and ${MON[j + 1]}: removes ${share(c.cut.gain)}% of the leaf's squared error`}
                  onpointerenter={() => (hover = { f: 0, thr: c.thr })} onpointerleave={() => (hover = null)} onfocus={() => (hover = { f: 0, thr: c.thr })}
                  onclick={() => doSplit(0, c.thr)} onkeydown={(e) => e.key === 'Enter' && doSplit(0, c.thr)}><title>{MON[j]} | {MON[j + 1]}: −{share(c.cut.gain)}% squared error</title></rect>
                {#if isBest}<text x={bx} y={gy(c.cut.gain) - 4} text-anchor="middle" class="bl">−{share(c.cut.gain)}%</text>{/if}
              {:else}
                <rect x={bx - bw / 2} y={SH - 20} width={bw} height="2" class="nobar" />
              {/if}
              <text x={bx} y={SH - 4} text-anchor="middle" class="tick sm">{MON[j][0]}|{MON[j + 1][0]}</text>
            {/each}
          </svg>
          <div class="sub">last month's growth: hover to preview a cut, click (or arrow keys + Enter) to make it</div>
          <svg width={sw} height={SH} role="slider" tabindex="0" aria-label="Candidate cuts on last month's growth" aria-valuemin={YLO} aria-valuemax={YHI}
            aria-valuenow={gCursor >= 0 ? +gCuts[gCursor].thr.toFixed(1) : undefined} aria-valuetext={gCursor >= 0 ? `cut at ${gCuts[gCursor].thr.toFixed(1)}%, removes ${share(gCuts[gCursor].gain)}% of squared error` : 'no cut selected'}
            onpointermove={gMove} onpointerleave={() => { hover = null; gCursor = -1; }} onclick={() => gCursor >= 0 && doSplit(1, gCuts[gCursor].thr)} onkeydown={gKey} class="gscan">
            <line x1="8" x2={sw - 8} y1={SH - 18} y2={SH - 18} class="zero" />
            {#if gCuts.length}
              <path d={'M' + gCuts.map((c) => `${gx(c.thr).toFixed(1)},${gy(c.gain).toFixed(1)}`).join('L')} class="gl" />
              {#if bestHere?.f === 1}<circle cx={gx(bestHere.thr)} cy={gy(bestHere.gain)} r="4" class="gbest" /><text x={gx(bestHere.thr)} y={gy(bestHere.gain) - 7} text-anchor="middle" class="bl">−{share(bestHere.gain)}%</text>{/if}
              {#if gCursor >= 0}<line x1={gx(gCuts[gCursor].thr)} x2={gx(gCuts[gCursor].thr)} y1="6" y2={SH - 18} class="gcur" /><text x={gx(gCuts[gCursor].thr) + 5} y="14" class="tick">{pct(gCuts[gCursor].thr)}: −{share(gCuts[gCursor].gain)}%</text>{/if}
            {:else}
              <text x={sw / 2} y={SH / 2} text-anchor="middle" class="tick">too few months in this leaf to cut</text>
            {/if}
            {#each [-20, 0, 20] as v}<text x={gx(v)} y={SH - 4} text-anchor="middle" class="tick sm">{v > 0 ? '+' : ''}{v}%</text>{/each}
          </svg>
        </div>
        <div class="panel">
          <div class="ph">Error as the tree grows (best split each time)</div>
          <svg width={EW} height={EH} role="img" aria-label={`Training error falls steadily as leaves are added; test error is lowest at ${bestTest?.k} leaves`}>
            {#each [0, 0.5, 1] as q}<line x1="30" x2={EW - 14} y1={ey(q * eMax)} y2={ey(q * eMax)} class="grid" /><text x="26" y={ey(q * eMax) + 4} text-anchor="end" class="tick sm">{(q * eMax).toFixed(0)}</text>{/each}
            <path d={path('tr')} class="etr" /><path d={path('te')} class="ete" />
            <text x={ex(MAXL) } y={ey(curve[curve.length - 1]?.tr ?? 0) + 14} text-anchor="end" class="lab tr">training</text>
            <text x={ex(MAXL)} y={ey(curve[curve.length - 1]?.te ?? 0) - 6} text-anchor="end" class="lab te">test (2023+)</text>
            <line x1={ex(Math.min(k, MAXL))} x2={ex(Math.min(k, MAXL))} y1="8" y2={EH - 24} class="gcur" />
            <circle cx={ex(Math.min(k, MAXL))} cy={ey(err.tr)} r="4" class="dtr" /><circle cx={ex(Math.min(k, MAXL))} cy={ey(err.te)} r="4" class="dte" />
            {#each [1, 10, 20, 30, 40] as v}<text x={ex(v)} y={EH - 8} text-anchor="middle" class="tick sm">{v}</text>{/each}
            <text x={EW - 14} y={EH - 8} text-anchor="end" class="tick sm" dx="0" dy="0"></text>
          </svg>
          <div class="read" aria-live="polite">
            <div><span class="stat-v">{leaves.length}</span><span class="stat-l">leaves</span></div>
            <div><span class="stat-v tr">{err.tr.toFixed(2)}</span><span class="stat-l">training RMSE, pp</span></div>
            <div><span class="stat-v te">{err.te.toFixed(2)}</span><span class="stat-l">test RMSE, pp</span></div>
          </div>
          {#if bestTest}<p class="hint">Test error is lowest at {bestTest.k} leaves ({bestTest.te.toFixed(2)} pp). Past that, new splits fit noise in the training years.</p>{/if}
        </div>
      </div>
    {:else}
      <div class="loading">Loading retail sales…</div>
    {/if}
  </div>
</Explorable>

<style>
  .gt { min-height: 330px; }
  .btn-sm { padding: .45em .85em; font-size: .8rem; }
  svg { display: block; overflow: visible; font-family: var(--font-ui); }
  .grid { stroke: var(--border); }
  .zero { stroke: var(--border-strong); stroke-width: 1.5; }
  .tick { font-size: 12px; fill: var(--muted); font-variant-numeric: tabular-nums; }
  .tick.sm { font-size: 12px; }
  .ax { font-size: 12px; fill: var(--muted); font-weight: 600; }
  .leaf { stroke: var(--border-strong); stroke-width: 1; cursor: pointer; transition: fill-opacity .3s; }
  .leaf:hover { stroke: var(--text-2); }
  .leaf.sel { stroke: var(--accent-2); stroke-width: 2.5; }
  .leaf:focus-visible { outline: none; stroke: var(--accent-2); stroke-width: 3; }
  .pt { pointer-events: none; stroke: var(--surface); stroke-width: .8; }
  .lv { font-size: 13px; font-weight: 700; fill: var(--text); paint-order: stroke; stroke: var(--surface); stroke-width: 3px; pointer-events: none; font-variant-numeric: tabular-nums; }
  .ln { font-size: 12px; fill: var(--muted); paint-order: stroke; stroke: var(--surface); stroke-width: 3px; pointer-events: none; }
  .cand { stroke: var(--accent-2); stroke-width: 2.5; stroke-dasharray: 5 4; pointer-events: none; }
  .panels { display: grid; grid-template-columns: 1fr 1fr; gap: 1.2rem; margin-top: .8rem; padding-top: .8rem; border-top: 1px solid var(--border); }
  @media (max-width: 760px) { .panels { grid-template-columns: 1fr; } }
  .ph { font-size: .84rem; font-weight: 650; color: var(--text); }
  .sub { font-size: .76rem; color: var(--muted); margin: .35rem 0 .1rem; }
  .bar { fill: var(--c-s1); fill-opacity: .55; cursor: pointer; }
  .bar:hover, .bar:focus-visible { fill-opacity: .9; outline: none; }
  .bar.best { fill: var(--accent-2); fill-opacity: .9; }
  .nobar { fill: var(--border-strong); }
  .bl { font-size: 12px; font-weight: 700; fill: var(--accent-2); }
  .gscan { cursor: crosshair; }
  .gscan:focus-visible { outline: 2px solid var(--accent-2); outline-offset: 2px; }
  .gl { fill: none; stroke: var(--c-s1); stroke-width: 2; }
  .gbest { fill: var(--accent-2); }
  .gcur { stroke: var(--text-2); stroke-dasharray: 3 3; }
  .etr { fill: none; stroke: var(--c-history); stroke-width: 2; }
  .ete { fill: none; stroke: var(--c-actual); stroke-width: 2.5; }
  .dtr { fill: var(--c-history); } .dte { fill: var(--c-actual); }
  .lab { font-size: 12px; font-weight: 650; paint-order: stroke; stroke: var(--surface); stroke-width: 3px; }
  .lab.tr { fill: var(--c-history); } .lab.te { fill: var(--c-actual); }
  .read { display: flex; gap: 1.4rem; margin-top: .3rem; }
  .read > div { display: flex; flex-direction: column; }
  .stat-v { font: 650 1.3rem/1.1 var(--font-ui); font-variant-numeric: tabular-nums; color: var(--text); }
  .stat-v.tr { color: var(--c-history); } .stat-v.te { color: var(--c-actual); }
  .stat-l { font-size: .74rem; color: var(--muted); }
  .hint { font-size: .78rem; color: var(--muted); margin: .4rem 0 0; }
  .loading { color: var(--muted); padding: 2rem 0; }
  @media (prefers-reduced-motion: reduce) { .leaf { transition: none; } }
</style>
