<script lang="ts">
  // "You draw it": sketch your own forecast, then compare with reality and with a model.
  import { onMount } from 'svelte';
  import * as d3 from 'd3';
  import Explorable from '../Explorable.svelte';
  import { loadSeries, holtWinters, mean, ym } from '../../lib/ts';
  import { C, fmt, watchLayout } from '../../lib/viz/theme';

  const ORIGIN = '2022-12-01', START = '2016-01-01', H = 12;
  let el: HTMLDivElement;
  let hist: { date: Date; value: number }[] = [], truth: { date: Date; value: number }[] = [], model: number[] = [];
  let drawn: (number | null)[] = $state(Array(H).fill(null));
  let revealed = $state(false);
  const complete = $derived(drawn.every((v) => v !== null));
  const yourMAE = $derived(complete ? mean(drawn.map((v, i) => Math.abs((v as number) - truth[i]?.value))) : NaN);
  const modelMAE = $derived(truth.length ? mean(model.map((v, i) => Math.abs(v - truth[i].value))) : NaN);

  async function load() {
    const s = await loadSeries('RSXFSN', { start: START });
    const o = s.data.findIndex((p) => +p.date === +new Date(ORIGIN + 'T00:00:00'));
    hist = s.data.slice(0, o + 1); truth = s.data.slice(o + 1, o + 1 + H);
    // a quick analyst's model: multiplicative Holt-Winters with fixed smoothing weights, fitted on 2016-2022
    model = holtWinters(hist.map((p) => p.value), 12, 0.3, 0.02, 0.3, H, true).forecast;
    draw();
  }

  function draw() {
    if (!el || !hist.length) return;
    const W = el.clientWidth, Ht = Math.max(300, Math.min(420, W * 0.5)), m = { l: 58, r: 58, t: 16, b: 30 };
    const dates = [...hist.slice(-36).map((p) => p.date), ...truth.map((p) => p.date)];
    const x = d3.scaleTime().domain(d3.extent(dates) as [Date, Date]).range([m.l, W - m.r]);
    const vals = [...hist.slice(-36).map((p) => p.value), ...truth.map((p) => p.value)];
    const y = d3.scaleLinear().domain([d3.min(vals)! * 0.9, d3.max(vals)! * 1.12]).nice().range([Ht - m.b, m.t]);
    const svg = d3.create('svg').attr('width', W).attr('height', Ht).attr('role', 'img').attr('aria-label', 'Draw your forecast for 2023');
    svg.append('g').attr('transform', `translate(${m.l},0)`).call(d3.axisLeft(y).ticks(5).tickFormat((d) => fmt(+d)).tickSize(-(W - m.l - m.r)))
      .call((g) => { g.select('.domain').remove(); g.selectAll('line').attr('stroke', C.border); g.selectAll('text').attr('fill', C.muted).attr('font-size', 12); });
    svg.append('g').attr('transform', `translate(0,${Ht - m.b})`).call(d3.axisBottom(x).ticks(6))
      .call((g) => { g.select('.domain').attr('stroke', C.border); g.selectAll('line').remove(); g.selectAll('text').attr('fill', C.muted).attr('font-size', 12); });
    const x0 = x(hist[hist.length - 1].date);
    svg.append('rect').attr('x', x0).attr('y', m.t).attr('width', W - m.r - x0).attr('height', Ht - m.t - m.b).attr('fill', C.forecast).attr('fill-opacity', revealed ? 0.03 : 0.07);
    if (!revealed) svg.append('text').attr('class', 'hint').attr('x', (x0 + W - m.r) / 2).attr('y', m.t + 22).attr('text-anchor', 'middle').attr('fill', C.text2).attr('font-size', 13).attr('font-weight', 600).text(complete ? 'Done? Press “Reveal what happened”' : 'Draw here: drag across 2023');
    const line = d3.line<any>().x((d) => x(d.date)).y((d) => y(d.value));
    svg.append('path').attr('d', line(hist.slice(-36))).attr('fill', 'none').attr('stroke', C.history).attr('stroke-width', 1.8);
    const last = hist[hist.length - 1];
    const mineData = () => [{ date: last.date, value: last.value }, ...truth.map((t, i) => ({ date: t.date, value: drawn[i] })).filter((d) => d.value !== null)];
    if (revealed) {
      svg.append('path').attr('d', line([last, ...truth.map((t, i) => ({ date: t.date, value: model[i] }))])).attr('fill', 'none').attr('stroke', C.fitted).attr('stroke-width', 2).attr('stroke-dasharray', '2,3');
      svg.append('path').attr('d', line([last, ...truth])).attr('fill', 'none').attr('stroke', C.actual).attr('stroke-width', 2.6).attr('class', 'yd-reveal');
    }
    const minePath = svg.append('path').attr('fill', 'none').attr('stroke', C.forecast).attr('stroke-width', 2.8).attr('stroke-linejoin', 'round');
    const dotsG = svg.append('g');
    const hintT = svg.select('text.hint');
    const update = () => {
      const mine = mineData();
      minePath.attr('d', line(mine));
      dotsG.selectAll('circle').data(mine.slice(1)).join('circle').attr('cx', (d: any) => x(d.date)).attr('cy', (d: any) => y(d.value as number)).attr('r', 3).attr('fill', C.forecast);
      if (!revealed) hintT.text(drawn.every((v) => v !== null) ? 'Done? Press “Reveal what happened”' : 'Draw here: drag across 2023');
    };
    update();
    if (revealed) {
      // direct end labels with simple collision avoidance (min 15px apart)
      const labs = [{ t: 'Actual', v: truth[H - 1].value, c: C.actual }, { t: 'Model', v: model[H - 1], c: C.fitted }, ...(complete ? [{ t: 'You', v: drawn[H - 1] as number, c: C.forecast }] : [])]
        .map((l) => ({ ...l, py: y(l.v) })).sort((a, b) => a.py - b.py);
      for (let k = 1; k < labs.length; k++) if (labs[k].py - labs[k - 1].py < 15) labs[k].py = labs[k - 1].py + 15;
      labs.forEach((l) => svg.append('text').attr('x', W - m.r + 6).attr('y', l.py + 4).attr('fill', l.c).attr('font-size', 12).attr('font-weight', 650).attr('paint-order', 'stroke').attr('stroke', C.surface).attr('stroke-width', 3).text(l.t));
    }
    // drawing interaction
    const set = (px: number, py: number) => {
      if (revealed) return;
      const d = x.invert(px);
      let i = truth.findIndex((t) => Math.abs(+t.date - +d) < 16 * 864e5);
      if (i < 0) return;
      const v = Math.max(y.domain()[0], Math.min(y.domain()[1], y.invert(py)));
      // fill gaps between the previous drag position and this one so a fast drag leaves no holes
      if (prevI !== null && prevI !== i) { const a = Math.min(prevI, i), b = Math.max(prevI, i); for (let k = a; k <= b; k++) drawn[k] = prevV! + ((v - prevV!) * (k - prevI)) / (i - prevI); }
      drawn[i] = v; prevI = i; prevV = v;
      for (let k = i - 1; k >= 0 && drawn[k] === null; k--) drawn[k] = v;
      update();
    };
    const zone = svg.append('rect').attr('x', x0).attr('y', m.t).attr('width', W - m.r - x0).attr('height', Ht - m.t - m.b).attr('fill', 'transparent').style('cursor', revealed ? 'default' : 'crosshair');
    let prevI: number | null = null, prevV: number | null = null;
    zone.call(d3.drag<SVGRectElement, unknown>().on('start', (ev) => { prevI = null; set(ev.x, ev.y); }).on('drag', (ev) => set(ev.x, ev.y)) as any);
    el.replaceChildren(svg.node()!);
  }

  // keyboard drawing: Left/Right pick a month, Up/Down move its value by $5 billion
  let kb = -1;
  function onKey(e: KeyboardEvent) {
    if (revealed || !truth.length) return;
    const k = e.key;
    if (!['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].includes(k)) return;
    e.preventDefault();
    const prev = (i: number) => (i > 0 ? (drawn[i - 1] ?? hist[hist.length - 1].value) : hist[hist.length - 1].value);
    if (kb < 0) kb = 0;
    else if (k === 'ArrowLeft') kb = Math.max(0, kb - 1);
    else if (k === 'ArrowRight') kb = Math.min(H - 1, kb + 1);
    if (drawn[kb] === null) drawn[kb] = prev(kb);
    if (k === 'ArrowUp' || k === 'ArrowDown') drawn[kb] = (drawn[kb] as number) + (k === 'ArrowUp' ? 5000 : -5000);
    draw();
  }
  function reset() { drawn = Array(H).fill(null); revealed = false; kb = -1; draw(); }
  function useModel() { drawn = model.slice(); draw(); }
  $effect(() => { revealed; draw(); });
  onMount(() => { load(); return watchLayout(el, draw); });
</script>

<Explorable kicker="Your turn first" title="Draw your forecast for 2023, then see what happened" caption={`U.S. retail sales (NSA, $ millions) through December 2022. Drag across the shaded area (or focus the chart and use the arrow keys) to sketch the next 12 months, then reveal. The dotted line is a simple seasonal model fitted to the same history: the kind of model you will build in this course.`}>
  {#snippet controls()}
    <button class="btn btn-primary btn-sm" disabled={!complete} onclick={() => (revealed = true)}>Reveal what happened</button>
    <button class="btn btn-sm" onclick={reset}>Start over</button>
    {#if !revealed}<button class="btn btn-ghost btn-sm" onclick={useModel}>Fill in with the model</button>{/if}
  {/snippet}
  {#snippet aside()}
    <div class="yd-side" aria-live="polite">
      {#if revealed}
        <div class="stat"><span class="stat-v" style="color:var(--c-forecast)">{fmt(yourMAE)}</span><span class="stat-l">Your average miss ($ millions per month)</span></div>
        <div class="stat"><span class="stat-v" style="color:var(--c-fitted)">{fmt(modelMAE)}</span><span class="stat-l">The model's average miss</span></div>
        <p class="yd-verdict">{yourMAE < modelMAE ? 'You beat the model. Did you copy last year’s pattern? That is exactly what the best simple models do (Chapter 3).' : 'The model wins. It remembered the seasonal shape: a big December, then a January slump. Hand-drawn forecasts often underestimate seasonality.'}</p>
      {:else}
        <p class="yd-hint">Things to think about while drawing:</p>
        <ul class="yd-list"><li>What happens every December?</li><li>Is the trend still rising?</li><li>How sure are you? (We will draw uncertainty next.)</li></ul>
        <p class="yd-hint">{drawn.filter((v) => v !== null).length} / 12 months drawn</p>
      {/if}
    </div>
  {/snippet}
  <!-- svelte-ignore a11y_no_noninteractive_tabindex a11y_no_noninteractive_element_interactions -->
  <div bind:this={el} class="yd-chart" role="application" tabindex="0" onkeydown={onKey} aria-label="Drawing area for 2023. Use the left and right arrow keys to pick a month and the up and down arrow keys to raise or lower it by 5 billion dollars."></div>
</Explorable>

<style>
  .yd-chart { min-height: 300px; touch-action: none; user-select: none; }
  .yd-chart:focus-visible { outline: 2px solid var(--accent-2); outline-offset: 4px; border-radius: 6px; }
  .yd-chart :global(.yd-reveal) { stroke-dasharray: 1500; stroke-dashoffset: 1500; animation: ydr 1.2s cubic-bezier(.2,0,0,1) forwards; }
  @keyframes ydr { to { stroke-dashoffset: 0; } }
  .yd-side { display: grid; gap: .9rem; font-size: .88rem; color: var(--text-2); }
  .yd-verdict { margin: 0; }
  .yd-hint { margin: 0; color: var(--muted); }
  .yd-list { margin: 0; padding-left: 1.1rem; }
</style>
