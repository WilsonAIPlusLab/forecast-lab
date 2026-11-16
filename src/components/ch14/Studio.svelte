<script lang="ts">
  // THE FORECAST STUDIO: pick a series, a cut-off date and a horizon; every method is scored on 48 rolling origins;
  // the fan chart uses ranges built from those real errors; an executive summary writes itself. Pure JS, no R needed.
  import { onMount, untrack } from 'svelte';
  import * as Plot from '@observablehq/plot';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, futureDates } from '../../lib/ts';
  import { C, css, plotStyle, watchLayout } from '../../lib/viz/theme';
  import { MODELS, modelInfo, runStudio, empiricalBands, type ModelKey } from './engine';
  import { STUDIO_SERIES, seriesById, adjText, fmtShort, fmtVal, fmtMiss, monYr, monthYear, isoMonth } from './series';
  import { makeSummary } from './summary';
  import { downloadPng, copyText, dodge } from './exportPng';

  const ALL: ModelKey[] = MODELS.map((m) => m.k);
  const HS = [6, 12, 18, 24];
  const START = '2010-01-01', K = 48, MIN_N = 84; // data from Jan 2010; at least 7 years before the cut-off
  const uid = Math.random().toString(36).slice(2, 7);

  let sid = $state('RSXFSN');
  let H = $state(12);
  let sel: ModelKey[] = $state([...ALL]);
  let pick: ModelKey | 'best' = $state('best');
  let data: { date: Date; value: number }[] = $state([]);
  let endIdx = $state(-1);
  let endDraft = $state(-1);
  let ready = $state(false);
  let status = $state('');
  let pendingEnd: string | null = null;
  let fanEl: HTMLDivElement, hzEl: HTMLDivElement;
  let timer: any;

  const meta = $derived(seriesById(sid));

  let loadSeq = 0;
  async function load(id: string) {
    const my = ++loadSeq;
    const prevEnd = endIdx >= 0 && data.length && endIdx < data.length - 1 ? isoMonth(data[endIdx].date) : null;
    const s = await loadSeries(id, { start: START });
    if (my !== loadSeq) return; // a newer request superseded this one
    const want = pendingEnd ?? prevEnd; pendingEnd = null;
    const div = seriesById(id).div;
    const d = s.data.map((p) => ({ date: p.date, value: p.value / div }));
    let idx = d.length - 1;
    if (want) { const j = d.findIndex((p) => isoMonth(p.date) === want); if (j >= 0) idx = j; }
    idx = Math.max(MIN_N - 1, Math.min(idx, d.length - 1));
    data = d; endIdx = idx; endDraft = idx;
  }

  // ── the run ──
  const res = $derived.by(() => {
    if (!data.length || endIdx < 0) return null;
    return runStudio(data.slice(0, endIdx + 1).map((p) => p.value), H, sel.length ? sel : ['snaive'], 12, K);
  });
  const run = $derived.by(() => {
    if (!res) return null;
    const train = data.slice(0, endIdx + 1);
    const featured: ModelKey = pick !== 'best' && res.models.includes(pick) ? pick : res.best;
    const [b50, b80] = empiricalBands(res, featured, [50, 80]);
    const last = train[train.length - 1];
    const dates = futureDates(last.date, H, 12);
    const fc = res.forecasts[featured];
    const rows = dates.map((date, i) => ({ date, f: fc[i], lo50: b50.lo[i], hi50: b50.hi[i], lo80: b80.lo[i], hi80: b80.hi[i] }));
    const actual = data.slice(endIdx + 1, endIdx + 1 + H);
    const inside = actual.filter((p, i) => p.value >= rows[i].lo80 && p.value <= rows[i].hi80).length;
    const evalStart = data[res.origins[0]].date;
    const summary = makeSummary({ s: meta, res, featured, lastDate: last.date, targetDate: dates[H - 1], evalStart, evalEnd: last.date,
      point: fc[H - 1], lo80: b80.lo[H - 1], hi80: b80.hi[H - 1], latest: last.value,
      sameMonth: train[endIdx + H - 12 * Math.ceil(H / 12)] }); // same calendar month as the target, latest year of data
    return { res, featured, rows, last, train, actual, inside, evalStart, summary };
  });

  const scoreOf = (k: ModelKey) => run?.res.scores.find((s) => s.k === k);
  const bestBy = $derived.by(() => {
    if (!run) return {} as Record<string, ModelKey>;
    const sc = run.res.scores, out: Record<string, ModelKey> = {};
    for (const m of ['MAE', 'RMSE', 'MASE'] as const) out[m] = sc.slice().sort((a, b) => a[m] - b[m])[0].k;
    out.ME = sc.slice().sort((a, b) => Math.abs(a.ME) - Math.abs(b.ME))[0].k;
    return out;
  });

  const title = $derived(run ? `${meta.label}: about ${fmtVal(meta, run.rows[H - 1].f)} by ${monthYear(run.rows[H - 1].date)}` : '');
  const subtitle = $derived(run ? `${modelInfo(run.featured).label} forecast with 50% and 80% ranges built from its errors at ${run.res.K} past forecast origins. ${meta.unitLong}, ${adjText(meta)}.` : '');
  const source = $derived(`Source: FRED, Federal Reserve Bank of St. Louis (${sid}); data from Jan 2010. Built in the Forecast Lab Studio.`);

  // ── charts ──
  // Direct labels at the right edge: bold for the highlighted series, regular for context. Text gets a halo.
  const labels = (lab: any[], x: () => any) => [700, 500].map((w) => Plot.text(lab.filter((d) => d.w === w), {
    x, y: 'vy', text: 'text', fill: (d: any) => d.fill, fontWeight: w, dx: 8, textAnchor: 'start', lineAnchor: 'middle', fontSize: 12,
    stroke: C.surface, strokeWidth: 3, paintOrder: 'stroke' }));
  function drawFan() {
    if (!fanEl || !run) return;
    const { rows, last, train, actual, featured } = run;
    const hist = train.slice(-72);
    const join = { date: last.date, f: last.value, lo50: last.value, hi50: last.value, lo80: last.value, hi80: last.value };
    const band = [join, ...rows];
    const act = actual.length ? [last, ...actual] : [];
    const vals = [...hist.map((p) => p.value), ...rows.flatMap((r) => [r.lo80, r.hi80]), ...actual.map((p) => p.value)];
    let lo = Math.min(...vals), hi = Math.max(...vals); const pad = (hi - lo) * 0.06; lo -= pad; hi += pad;
    const W = fanEl.clientWidth, Ht = Math.max(300, Math.min(400, W * 0.52)), mt = 22, mb = 30;
    const end = rows[rows.length - 1];
    const lab = dodge([
      { v: end.f, text: modelInfo(featured).short, fill: css('--accent-text'), w: 700 },
      { v: end.hi80, text: '80% range', fill: C.muted, w: 500 },
      { v: end.hi50, text: '50%', fill: C.muted, w: 500 },
      ...(actual.length === rows.length ? [{ v: actual[actual.length - 1].value, text: 'Actual', fill: C.actual, w: 700 }] : []),
    ], [lo, hi], Ht - mt - mb, 15);
    const tipRows = [
      ...hist.map((p) => ({ date: p.date, y: p.value, t: `${monYr(p.date)}\n${meta.label}: ${fmtShort(meta, p.value)} ${meta.unitAxis}` })),
      ...rows.map((r, i) => ({ date: r.date, y: r.f, t: `${monYr(r.date)} (${i + 1} mo ahead)\nForecast: ${fmtShort(meta, r.f)} ${meta.unitAxis}\n50% range: ${fmtShort(meta, r.lo50)} to ${fmtShort(meta, r.hi50)}\n80% range: ${fmtShort(meta, r.lo80)} to ${fmtShort(meta, r.hi80)}` + (actual[i] ? `\nActual: ${fmtShort(meta, actual[i].value)}` : '') })),
    ];
    const chart = Plot.plot({
      width: W, height: Ht, marginLeft: 58, marginRight: 96, marginTop: mt, marginBottom: mb, style: plotStyle(),
      x: { label: null }, y: { domain: [lo, hi], grid: true, label: `↑ ${meta.unitAxis}`, tickFormat: (v: number) => fmtShort(meta, v) },
      marks: [
        Plot.areaY(band, { x: 'date', y1: 'lo80', y2: 'hi80', fill: C.forecast, fillOpacity: 0.16 }),
        Plot.areaY(band, { x: 'date', y1: 'lo50', y2: 'hi50', fill: C.forecast, fillOpacity: 0.3 }),
        Plot.ruleX([last.date], { stroke: C.borderStrong, strokeDasharray: '4,4' }),
        Plot.text([last.date], { x: (d: any) => d, frameAnchor: 'top', dy: -14, textAnchor: 'end', dx: -4, text: () => `Data through ${monYr(last.date)}`, fill: C.muted, fontSize: 12 }),
        Plot.text([last.date], { x: (d: any) => d, frameAnchor: 'top', dy: -14, textAnchor: 'start', dx: 6, text: () => 'Forecast starts', fill: C.muted, fontSize: 12 }),
        Plot.lineY(hist, { x: 'date', y: 'value', stroke: C.history, strokeWidth: 2 }),
        ...(act.length ? [Plot.lineY(act, { x: 'date', y: 'value', stroke: C.actual, strokeWidth: 2.2, strokeDasharray: '5,3' })] : []),
        Plot.lineY(band, { x: 'date', y: 'f', stroke: C.forecast, strokeWidth: 2.5 }),
        ...labels(lab, () => end.date),
        Plot.tip(tipRows, Plot.pointerX({ x: 'date', y: 'y', title: 't', maxRadius: 60 })),
      ],
    });
    chart.setAttribute('role', 'img');
    chart.setAttribute('aria-label', `${title}. 80% range ${fmtVal(meta, end.lo80)} to ${fmtVal(meta, end.hi80)}.`);
    fanEl.replaceChildren(chart);
  }

  function drawHorizon() {
    if (!hzEl || !run) return;
    const { res, featured } = run;
    const rows = res.scores.flatMap((sc) => sc.maeH.map((v, i) => ({ h: i + 1, v, k: sc.k })));
    const ref = res.ref.maeH.map((v, i) => ({ h: i + 1, v }));
    const showRef = featured !== 'snaive';
    const max = Math.max(...rows.map((r) => r.v), ...(showRef ? ref.map((r) => r.v) : [])) * 1.08;
    const W = hzEl.clientWidth, Ht = 250, mt = 12, mb = 36;
    const fRows = rows.filter((r) => r.k === featured), others = rows.filter((r) => r.k !== featured && r.k !== 'snaive');
    const items: any[] = [{ v: fRows[H - 1].v, text: modelInfo(featured).short, fill: css('--accent-text'), w: 700 }];
    if (showRef) items.push({ v: ref[H - 1].v, text: 'Seasonal naive', fill: C.text2, w: 500 });
    if (res.best !== featured && res.best !== 'snaive') items.push({ v: res.scores.find((s) => s.k === res.best)!.maeH[H - 1], text: `${modelInfo(res.best).short} (best)`, fill: C.text2, w: 500 });
    const lab = dodge(items, [0, max], Ht - mt - mb, 15);
    const chart = Plot.plot({
      width: W, height: Ht, marginLeft: 58, marginRight: 112, marginTop: mt, marginBottom: mb, style: plotStyle(),
      x: { label: 'Months ahead →', domain: [1, H], ticks: Math.min(H, 12), tickFormat: (d: number) => String(d) },
      y: { domain: [0, max], grid: true, label: `↑ Typical miss (MAE, ${meta.unitAxis})`, tickFormat: (v: number) => fmtShort(meta, v) },
      marks: [
        Plot.ruleY([0], { stroke: C.borderStrong, strokeWidth: 1.5 }),
        Plot.lineY(others, { x: 'h', y: 'v', z: 'k', stroke: C.muted, strokeOpacity: 0.4, strokeWidth: 1.25 }),
        ...(showRef ? [Plot.lineY(ref, { x: 'h', y: 'v', stroke: C.text2, strokeWidth: 2, strokeDasharray: '4,4' })] : []),
        Plot.lineY(fRows, { x: 'h', y: 'v', stroke: C.forecast, strokeWidth: 3 }),
        Plot.dot(fRows, { x: 'h', y: 'v', fill: C.forecast, r: 3 }),
        ...labels(lab, () => H),
        Plot.tip([...rows, ...(sel.includes('snaive') ? [] : ref.map((r) => ({ ...r, k: 'snaive' as ModelKey })))], Plot.pointer({ x: 'h', y: 'v', title: (d: any) => `${modelInfo(d.k).label}${d.k === 'snaive' && !sel.includes('snaive') ? ' (reference)' : ''}\n${d.h} month${d.h > 1 ? 's' : ''} ahead\nMAE: ${fmtShort(meta, d.v)} ${meta.unitAxis}` })),
      ],
    });
    chart.setAttribute('role', 'img');
    chart.setAttribute('aria-label', `Average miss by horizon. ${modelInfo(featured).label}: ${fmtMiss(meta, fRows[0].v)} one month ahead, ${fmtMiss(meta, fRows[H - 1].v)} ${H} months ahead.`);
    hzEl.replaceChildren(chart);
  }

  $effect(() => { run; drawFan(); drawHorizon(); });
  $effect(() => { const id = sid; untrack(() => load(id)); });

  // ── URL state (deep links for instructors) ──
  $effect(() => {
    if (!ready || !data.length || endIdx < 0) return;
    const p = new URLSearchParams(location.search);
    p.set('s', sid); p.set('end', isoMonth(data[endIdx].date)); p.set('h', String(H));
    p.set('m', sel.join(',')); p.set('f', pick);
    history.replaceState(history.state, '', `${location.pathname}?${p.toString()}${location.hash}`);
  });

  onMount(() => {
    const p = new URLSearchParams(location.search);
    const s = p.get('s'); if (s && STUDIO_SERIES.some((x) => x.id === s)) sid = s;
    const h = +(p.get('h') || 0); if (HS.includes(h)) H = h;
    const m = p.get('m'); if (m) { const v = m.split(',').filter((k) => ALL.includes(k as ModelKey)) as ModelKey[]; if (v.length) sel = v; }
    const f = p.get('f'); if (f && (f === 'best' || ALL.includes(f as ModelKey))) pick = f as any;
    const e = p.get('end'); if (e && /^\d{4}-\d{2}$/.test(e)) pendingEnd = e;
    if (e && (!s || s === 'RSXFSN')) load(sid); // series unchanged, so the effect will not re-run: reload to apply the cut-off
    ready = true;
    const off1 = watchLayout(fanEl, drawFan), off2 = watchLayout(hzEl, drawHorizon);
    return () => { off1(); off2(); clearTimeout(timer); };
  });

  // ── controls ──
  function onDrag(v: number) { endDraft = v; clearTimeout(timer); timer = setTimeout(() => (endIdx = endDraft), 120); }
  function commit() { clearTimeout(timer); endIdx = endDraft; }
  function toggle(k: ModelKey) {
    if (sel.includes(k)) { if (sel.length > 1) sel = sel.filter((x) => x !== k); }
    else sel = ALL.filter((x) => x === k || sel.includes(x));
  }
  function reset() { sid = 'RSXFSN'; H = 12; sel = [...ALL]; pick = 'best'; if (data.length) { endIdx = endDraft = data.length - 1; } }
  function flash(msg: string) { status = msg; setTimeout(() => { if (status === msg) status = ''; }, 2600); }
  async function copySummary() { if (run) flash((await copyText(run.summary.text)) ? 'Summary copied to the clipboard.' : 'Copy failed: select the text and copy it by hand.'); }
  async function copyLink() { flash((await copyText(location.href)) ? 'Link to this exact view copied.' : 'Copy failed: copy the address bar instead.'); }
  async function png() {
    const svg = fanEl?.querySelector('svg'); if (!svg || !run) return;
    await downloadPng(svg as SVGSVGElement, { title, subtitle, source, name: `forecast-${sid.toLowerCase()}-${isoMonth(run.last.date)}-h${H}` });
    flash('PNG downloaded.');
  }

  const endLabel = $derived(data.length && endDraft >= 0 ? monYr(data[Math.min(endDraft, data.length - 1)].date) : '');
  const isLatest = $derived(data.length > 0 && endDraft === data.length - 1);
  const pct = (v: number) => `${(v * 100).toFixed(0)}%`;
</script>

<Explorable wide kicker="The Forecast Studio" title="Ship a forecast: pick a series, score every method, brief the boss"
  caption={`Everything here runs in your browser in a fraction of a second. Each method is re-fitted and scored at each of the last ${K} months before the cut-off, forecasting 1 to ${H} months ahead each time (rolling-origin evaluation). The fan chart's ranges come from those real errors, not from a formula. Move <b>Data through</b> back to see how a forecast made then turned out (gold line). The address bar updates as you go, so you can share or bookmark any view.`}>
  {#snippet controls()}
    <label class="ctl">
      <span class="ctl-l">Series</span>
      <select bind:value={sid} aria-label="Series to forecast">
        {#each STUDIO_SERIES as s}<option value={s.id}>{s.label} ({s.adj})</option>{/each}
      </select>
    </label>
    {#if data.length}
      <label class="ctl sl">
        <span class="ctl-l">Data through</span>
        <input type="range" min={MIN_N - 1} max={data.length - 1} value={endDraft}
          oninput={(e) => onDrag(+(e.currentTarget as HTMLInputElement).value)} onchange={commit}
          aria-label="Last month of data the forecaster can see" aria-valuetext={`${endLabel}${isLatest ? ', the latest month available' : ''}`} />
        <b>{endLabel}</b>{#if isLatest}<span class="pill">latest</span>{/if}
      </label>
    {/if}
    <div class="ctl">
      <span class="ctl-l" id="hz-{uid}">Horizon</span>
      <div class="seg" role="group" aria-labelledby="hz-{uid}">
        {#each HS as h}<button class:on={H === h} aria-pressed={H === h} onclick={() => (H = h)}>{h} mo</button>{/each}
      </div>
    </div>
    <button class="btn btn-ghost btn-sm reset" onclick={reset}>Reset</button>
  {/snippet}

  <div class="studio">
    <p class="meta-line"><b>{meta.noun[0].toUpperCase() + meta.noun.slice(1)}</b>, FRED <code>{sid}</code>: {meta.unitLong}, <b>{adjText(meta)}</b>. {meta.note}</p>

    {#if run}
      <div class="kpis" aria-live="polite">
        <div class="kpi">
          <div class="kpi-l">Forecast for {monYr(run.rows[H - 1].date)}</div>
          <div class="kpi-v">{fmtShort(meta, run.rows[H - 1].f)}</div>
          <div class="kpi-s">{meta.unitAxis}</div>
        </div>
        <div class="kpi">
          <div class="kpi-l">80% range</div>
          <div class="kpi-v sm">{fmtShort(meta, run.rows[H - 1].lo80)} to {fmtShort(meta, run.rows[H - 1].hi80)}</div>
          <div class="kpi-s">from {run.res.errors[run.featured][H - 1].length} past {H}-month-ahead errors</div>
        </div>
        <div class="kpi">
          <div class="kpi-l">{run.featured === run.res.best ? 'Best method' : 'Chosen method'}</div>
          <div class="kpi-v sm">{modelInfo(run.featured).label}</div>
          <div class="kpi-s">MASE {scoreOf(run.featured)?.MASE.toFixed(2)}{run.featured !== 'snaive' ? `, ${pct(Math.abs(1 - scoreOf(run.featured)!.MAE / run.res.ref.MAE))} ${scoreOf(run.featured)!.MAE <= run.res.ref.MAE ? 'smaller' : 'larger'} misses than seasonal naive` : ''}</div>
        </div>
        <div class="kpi">
          <div class="kpi-l">Typical miss, 1 month ahead</div>
          <div class="kpi-v">{fmtShort(meta, scoreOf(run.featured)!.maeH[0])}</div>
          <div class="kpi-s">{fmtShort(meta, scoreOf(run.featured)!.maeH[H - 1])} at {H} months ahead</div>
        </div>
      </div>
    {/if}

    <div class="row1">
      <section class="panel" aria-labelledby="fan-h-{uid}">
        <h4 id="fan-h-{uid}" class="ph">{title}</h4>
        <p class="psub">{subtitle}</p>
        <div bind:this={fanEl} class="chart fan"></div>
        {#if run && run.actual.length}
          <p class="backtest"><span class="sw-act"></span>What really happened: <b>{run.inside} of {run.actual.length}</b> months landed inside the 80% range{run.actual.length < H ? ` (only ${run.actual.length} months of actual data exist after the cut-off)` : ''}. A well-calibrated 80% range would catch about {Math.round(0.8 * run.actual.length)}.</p>
        {/if}
      </section>

      <section class="panel score" aria-labelledby="sc-h-{uid}">
        <h4 id="sc-h-{uid}" class="ph">Scorecard</h4>
        <p class="psub">Average over horizons 1–{H} at {run?.res.K ?? K} origins. Lower is better; green marks the best. Tick a method to include it; choose one to chart it.</p>
        {#if run}
          <div class="tw">
            <table>
              <thead><tr><th scope="col"><span class="sr">Include</span></th><th scope="col">Method</th><th scope="col" title="Mean absolute error">MAE</th><th scope="col" title="Root mean squared error">RMSE</th><th scope="col" title="Mean absolute scaled error: below 1 beats in-sample seasonal naive">MASE</th><th scope="col" title="Mean error: positive = forecasts too low">Bias</th></tr></thead>
              <tbody>
                {#each MODELS as m}
                  {@const sc = scoreOf(m.k)}
                  <tr class:on={run.featured === m.k} class:off={!sc}>
                    <td><input type="checkbox" checked={sel.includes(m.k)} onchange={() => toggle(m.k)} aria-label={`Include ${m.label}`} /></td>
                    <td class="mname">
                      <label class="pickl">
                        <input type="radio" name="feat-{uid}" checked={run.featured === m.k} disabled={!sc} onchange={() => (pick = m.k)} aria-label={`Chart ${m.label}`} />
                        <span title={m.desc}>{m.label}</span>
                        {#if run.res.best === m.k}<span class="pill good">best</span>{/if}
                      </label>
                    </td>
                    {#if sc}
                      <td class:best={bestBy.MAE === m.k}>{fmtShort(meta, sc.MAE)}</td>
                      <td class:best={bestBy.RMSE === m.k}>{fmtShort(meta, sc.RMSE)}</td>
                      <td class:best={bestBy.MASE === m.k}>{sc.MASE.toFixed(2)}</td>
                      <td class:best={bestBy.ME === m.k}>{fmtShort(meta, sc.ME)}</td>
                    {:else}
                      <td colspan="4" class="na">not included</td>
                    {/if}
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
          <label class="follow"><input type="checkbox" checked={pick === 'best'} onchange={(e) => (pick = (e.currentTarget as HTMLInputElement).checked ? 'best' : run!.featured)} /> Always chart the best method</label>
          <p class="note">Units: {meta.unitAxis}. The combination averages the smoothing models you have ticked{sel.some((k) => modelInfo(k).kind === 'smoothing') ? '' : ' (none are ticked, so it averages the benchmarks)'}.</p>
        {/if}
      </section>
    </div>

    <div class="row2">
      <section class="panel" aria-labelledby="hz-h-{uid}">
        <h4 id="hz-h-{uid}" class="ph">{run ? `Misses grow from ${fmtShort(meta, scoreOf(run.featured)!.maeH[0])} to ${fmtShort(meta, scoreOf(run.featured)!.maeH[H - 1])} as the horizon stretches` : 'Accuracy by horizon'}</h4>
        <p class="psub">Typical miss (MAE) at each horizon. Violet: the charted method. Dashed: seasonal naive, the benchmark to beat. Grey: the others.</p>
        <div bind:this={hzEl} class="chart hz"></div>
      </section>

      <section class="panel brief" aria-labelledby="sum-h-{uid}">
        <h4 id="sum-h-{uid}" class="ph">Executive summary</h4>
        <p class="psub">Written from the numbers on this page. Edit it before you send it: you know things the model doesn't.</p>
        {#if run}
          <blockquote class="sum" aria-live="polite">{run.summary.text}</blockquote>
          <div class="acts">
            <button class="btn btn-primary btn-sm" onclick={copySummary}>Copy summary</button>
            <button class="btn btn-sm" onclick={png}>Download chart (PNG)</button>
            <button class="btn btn-ghost btn-sm" onclick={copyLink}>Copy link to this view</button>
          </div>
          <p class="status" role="status">{status}</p>
        {/if}
      </section>
    </div>

    <div class="more">
      <details>
        <summary>How the ranges are built (and their limits)</summary>
        <div class="dt">
          <p>The shaded ranges do not come from a model's formula. For each horizon <i>h</i>, the Studio collects every error the charted method made when it forecast <i>h</i> months ahead from one of the past {K} origins, then adds the 25th and 75th percentiles of those errors to the forecast (the 50% range) and the 10th and 90th percentiles (the 80% range).</p>
          <ul>
            <li><b>Honest about this method's real track record</b>, including any bias: if it has tended to over-forecast, the range sits below the line.</li>
            <li><b>It assumes the next {H} months look like the last four years.</b> A track record that includes 2020 gives huge ranges; one from a calm period can be too narrow.</li>
            <li><b>Few errors per horizon</b> ({K} at one month ahead, fewer further out), so the band edges are themselves rough. We skip a 95% range: it would rest on the one or two most extreme misses.</li>
            <li>Parameters are re-estimated at every origin by minimising one-step squared errors, so no origin sees data from its own future.</li>
          </ul>
        </div>
      </details>
      {#if run}
        <details>
          <summary>View the forecast as a table</summary>
          <div class="tw dt">
            <table>
              <thead><tr><th scope="col">Month</th><th scope="col">Forecast</th><th scope="col">50% range</th><th scope="col">80% range</th>{#if run.actual.length}<th scope="col">Actual</th>{/if}</tr></thead>
              <tbody>
                {#each run.rows as r, i}
                  <tr><td>{monYr(r.date)}</td><td>{fmtShort(meta, r.f)}</td><td>{fmtShort(meta, r.lo50)} to {fmtShort(meta, r.hi50)}</td><td>{fmtShort(meta, r.lo80)} to {fmtShort(meta, r.hi80)}</td>{#if run.actual.length}<td>{run.actual[i] ? fmtShort(meta, run.actual[i].value) : '—'}</td>{/if}</tr>
                {/each}
              </tbody>
            </table>
            <p class="note">{meta.unitLong}, {adjText(meta)}. <a href={`https://fred.stlouisfed.org/series/${sid}`} target="_blank" rel="noopener">FRED page for {sid}</a>.</p>
          </div>
        </details>
      {/if}
    </div>
  </div>
</Explorable>

<style>
  .ctl { display: inline-flex; align-items: center; gap: .55rem; }
  .ctl-l { font-size: .78rem; font-weight: 650; color: var(--muted); }
  select { font: 600 .84rem var(--font-ui); color: var(--text); background: var(--bg); border: 1px solid var(--border-strong); border-radius: 9px; padding: .38rem .6rem; }
  select:focus-visible { outline: 2px solid var(--accent-2); outline-offset: 1px; }
  .ctl.sl input { width: 170px; }
  .ctl.sl b { font: 600 .82rem var(--font-ui); font-variant-numeric: tabular-nums; color: var(--text); min-width: 7ch; }
  .reset { margin-left: auto; }
  .pill { font-size: .68rem; font-weight: 700; padding: .08rem .42rem; border-radius: 999px; background: var(--surface-3); color: var(--text-2); }
  .pill.good { background: color-mix(in srgb, var(--good) 16%, transparent); color: var(--good); margin-left: .35rem; }

  .studio { display: flex; flex-direction: column; gap: 1rem; }
  .meta-line { margin: 0; font-size: .86rem; color: var(--text-2); }
  .kpis { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: .7rem; }
  @media (max-width: 860px) { .kpis { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
  .kpi { background: var(--bg-2); border: 1px solid var(--border); border-radius: var(--radius-sm); padding: .7rem .85rem; min-width: 0; }
  .kpi-l { font-size: .74rem; font-weight: 600; color: var(--muted); }
  .kpi-v { font: 650 1.45rem/1.2 var(--font-ui); font-variant-numeric: tabular-nums; color: var(--text); margin: .15rem 0 .1rem; }
  .kpi-v.sm { font-size: 1.05rem; line-height: 1.35; }
  .kpi-s { font-size: .74rem; color: var(--text-2); line-height: 1.4; }

  .row1 { display: grid; grid-template-columns: minmax(0, 1.65fr) minmax(0, 1fr); gap: 1rem; }
  .row2 { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 1rem; }
  @container (max-width: 1100px) { .row1 { grid-template-columns: 1fr; } }
  @media (max-width: 980px) { .row1, .row2 { grid-template-columns: 1fr; } }
  .panel { border: 1px solid var(--border); border-radius: var(--radius-sm); padding: .85rem .95rem .8rem; min-width: 0; background: var(--surface); }
  .ph { margin: 0; font: 650 .98rem/1.35 var(--font-ui); color: var(--text); text-wrap: balance; }
  .psub { margin: .2rem 0 .6rem; font-size: .78rem; color: var(--muted); line-height: 1.45; }
  .chart.fan { min-height: 300px; }
  .chart.hz { min-height: 250px; }
  .backtest { font-size: .8rem; color: var(--text-2); margin: .4rem 0 0; }
  .sw-act { display: inline-block; width: 16px; border-top: 2.5px dashed var(--c-actual); vertical-align: middle; margin-right: .45rem; }

  .tw { overflow-x: auto; }
  .score table { font-size: .8rem; margin: 0 0 .5rem; width: 100%; }
  table th, table td { padding: .34rem .35rem; text-align: right; }
  table th:nth-child(-n+2), table td:nth-child(-n+2) { text-align: left; }
  .score td { font-variant-numeric: tabular-nums; }
  .score tr.on { background: var(--surface-2); }
  .score tr.on .mname { color: var(--text); font-weight: 650; }
  .score tr.off td { color: var(--muted); }
  .score td.best { color: var(--good); font-weight: 700; }
  .score td.na { text-align: left; font-style: italic; font-size: .74rem; }
  .pickl { display: inline-flex; align-items: center; gap: .4rem; cursor: pointer; white-space: nowrap; }
  input[type='radio'], input[type='checkbox'] { accent-color: var(--accent); margin: 0; }
  .follow { display: flex; align-items: center; gap: .45rem; font-size: .78rem; color: var(--text-2); cursor: pointer; }
  .note { font-size: .74rem; color: var(--muted); margin: .4rem 0 0; }
  .sr { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); }

  .brief .sum { margin: 0 0 .8rem; padding: .85rem 1rem; border-left: 3px solid var(--ch, var(--accent)); background: var(--bg-2); border-radius: 0 var(--radius-sm) var(--radius-sm) 0; font-size: .9rem; line-height: 1.62; color: var(--text); text-wrap: pretty; }
  .acts { display: flex; flex-wrap: wrap; gap: .5rem; }
  .status { min-height: 1.2em; font-size: .78rem; color: var(--good); margin: .45rem 0 0; }

  .more { display: flex; flex-direction: column; gap: .4rem; }
  .more summary { cursor: pointer; font-size: .86rem; font-weight: 600; color: var(--text-2); }
  .dt { font-size: .84rem; color: var(--text-2); padding: .4rem 0 .2rem; }
  .dt ul { margin: .3rem 0; padding-left: 1.2rem; }
  .dt table { font-size: .8rem; font-variant-numeric: tabular-nums; }
</style>
