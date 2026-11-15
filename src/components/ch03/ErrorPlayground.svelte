<script lang="ts">
  import { onMount } from 'svelte';
  import * as d3 from 'd3';
  import Explorable from '../Explorable.svelte';
  import { C, watchLayout } from '../../lib/viz/theme';

  // Drag the forecast dots and watch four error metrics react.
  const actual = [102, 98, 105, 110, 107, 115, 120, 118];
  const presets: Record<string, number[]> = {
    'Many small misses': actual.map((a, i) => a + (i % 2 ? 4 : -4)),
    'One big miss': actual.map((a, i) => (i === 5 ? a - 32 : a)),
    'Always too low': actual.map((a) => a - 6),
    Perfect: actual.slice(),
  };
  let fc = $state(presets['Many small misses'].slice());
  let el: HTMLDivElement;
  let active = $state('Many small misses');

  const e = $derived(actual.map((a, i) => a - fc[i]));
  const m = $derived({
    ME: e.reduce((s, x) => s + x, 0) / e.length,
    MAE: e.reduce((s, x) => s + Math.abs(x), 0) / e.length,
    RMSE: Math.sqrt(e.reduce((s, x) => s + x * x, 0) / e.length),
    MAPE: (100 * e.reduce((s, x, i) => s + Math.abs(x / actual[i]), 0)) / e.length,
  });

  function draw() {
    if (!el) return;
    const W = el.clientWidth, H = 260, ml = 40, mr = 70, mt = 12, mb = 28;
    const x = d3.scalePoint<number>().domain(actual.map((_, i) => i)).range([ml + 20, W - mr - 20]);
    const y = d3.scaleLinear().domain([70, 145]).range([H - mb, mt]);
    const svg = d3.create('svg').attr('width', W).attr('height', H).attr('role', 'img').attr('aria-label', 'Eight actual values (gold) and eight draggable forecast points (purple), with red bars showing each error');
    svg.append('g').attr('transform', `translate(${ml},0)`).call(d3.axisLeft(y).ticks(5).tickSize(-(W - ml - mr))).call((g) => { g.selectAll('line').attr('stroke', C.border); g.select('.domain').remove(); g.selectAll('text').attr('fill', C.muted).attr('font-size', 12); });
    svg.append('g').attr('transform', `translate(0,${H - mb})`).call(d3.axisBottom(x).tickFormat((i) => `t${+i + 1}`)).call((g) => { g.select('.domain').attr('stroke', C.border); g.selectAll('line').remove(); g.selectAll('text').attr('fill', C.muted).attr('font-size', 12); });
    const err = svg.append('g');
    const line = d3.line<number>().x((_, i) => x(i)!).y((v) => y(v));
    svg.append('path').attr('d', line(actual)).attr('fill', 'none').attr('stroke', C.actual).attr('stroke-width', 2).attr('stroke-dasharray', '5,3');
    svg.selectAll('circle.a').data(actual).join('circle').attr('cx', (_, i) => x(i)!).attr('cy', (v) => y(v)).attr('r', 4).attr('fill', C.actual);
    const last = actual.length - 1;
    svg.append('text').attr('x', x(last)! + 14).attr('y', y(actual[last]) - 6).attr('fill', C.actual).attr('font-size', 12).attr('font-weight', 700).text('Actual');
    const flabel = svg.append('text').attr('x', x(last)! + 14).attr('fill', C.forecast).attr('font-size', 12).attr('font-weight', 700).text('Forecast');
    const fpath = svg.append('path').attr('fill', 'none').attr('stroke', C.forecast).attr('stroke-width', 2.2);
    const render = () => {
      err.selectAll('line').data(fc).join('line').attr('x1', (_, i) => x(i)!).attr('x2', (_, i) => x(i)!).attr('y1', (v) => y(v)).attr('y2', (_, i) => y(actual[i]))
        .attr('stroke', C.danger).attr('stroke-width', (v, i) => 1.5 + Math.min(6, Math.abs(v - actual[i]) / 5)).attr('stroke-opacity', 0.6);
      fpath.attr('d', line(fc));
      flabel.attr('y', y(fc[last]) + (fc[last] > actual[last] ? -6 : 16));
      dots.attr('cy', (v) => y(v));
    };
    const dots = svg.selectAll('circle.f').data(fc).join('circle').attr('class', 'f').attr('cx', (_, i) => x(i)!).attr('r', 9).attr('fill', C.forecast).attr('stroke', C.surface).attr('stroke-width', 2.5)
      .style('cursor', 'ns-resize').attr('tabindex', 0).attr('aria-label', (_, i) => `Forecast for period ${i + 1}; use arrow keys to move`)
      .call(d3.drag<SVGCircleElement, number>().on('drag', function (ev, _d) {
        const i = dots.nodes().indexOf(this); fc[i] = Math.round(Math.max(72, Math.min(143, y.invert(ev.y)))); active = ''; render();
      }))
      .on('keydown', function (ev: KeyboardEvent) {
        const i = dots.nodes().indexOf(this as any); if (ev.key === 'ArrowUp') fc[i] = Math.min(143, fc[i] + 2); else if (ev.key === 'ArrowDown') fc[i] = Math.max(72, fc[i] - 2); else return; ev.preventDefault(); active = ''; render();
      });
    render();
    el.replaceChildren(svg.node()!);
  }
  function preset(k: string) { fc = presets[k].slice(); active = k; draw(); }
  onMount(() => { draw(); return watchLayout(el, draw); });
  const f1 = (v: number) => v.toFixed(1);
</script>

<Explorable title="Drag the forecast: how each error metric keeps score" caption="Purple dots are your forecast; drag them (or focus one and use ↑ ↓). Gold is what actually happened, and red bars are the errors. Try the presets: <b>Many small misses</b> and <b>One big miss</b> have the same MAE (4.0), but RMSE punishes the single big miss far more. <b>Always too low</b> reveals bias, which MAE cannot see but ME can.">
  {#snippet controls()}
    <div class="seg" role="group" aria-label="Presets">
      {#each Object.keys(presets) as k}<button class:on={active === k} onclick={() => preset(k)}>{k}</button>{/each}
    </div>
  {/snippet}
  {#snippet aside()}
    <div class="ms">
      <div class="stat"><span class="stat-v">{f1(m.MAE)}</span><span class="stat-l"><b>MAE</b>: average size of the miss</span></div>
      <div class="stat"><span class="stat-v">{f1(m.RMSE)}</span><span class="stat-l"><b>RMSE</b>: squares errors first, so big misses dominate</span></div>
      <div class="stat"><span class="stat-v">{f1(m.MAPE)}%</span><span class="stat-l"><b>MAPE</b>: miss as a % of the actual value</span></div>
      <div class="stat"><span class="stat-v" class:neg={Math.abs(m.ME) > 2}>{m.ME > 0 ? '+' : ''}{f1(m.ME)}</span><span class="stat-l"><b>ME (bias)</b>: positive means you forecast too low on average</span></div>
      <div class="ratio">RMSE ÷ MAE = <b>{m.MAE > 0 ? (m.RMSE / m.MAE).toFixed(2) : '—'}</b><br /><span>1.00 means all misses are equal; higher means a few big ones.</span></div>
    </div>
  {/snippet}
  <div bind:this={el}></div>
</Explorable>

<style>
  .ms { display: grid; gap: .85rem; }
  .ms .stat-l { line-height: 1.35; }
  .neg { color: var(--warm) !important; }
  .ratio { font-size: .8rem; color: var(--text-2); border-top: 1px dashed var(--border); padding-top: .7rem; }
  .ratio span { color: var(--muted); font-size: .75rem; }
</style>
