<script lang="ts">
  // Wording workshop: for each of five claims in an executive summary, pick the strongest sentence and see why the
  // others are weak. The chosen sentences assemble into a paragraph, with weak ones flagged.
  // Numbers: the Forecast Studio's default view (retail sales, data through September 2026) and Chapter 4's car-sales model.
  interface Opt { text: string; good: boolean; why: string }
  interface Claim { key: string; label: string; ask: string; opts: Opt[] }
  const CLAIMS: Claim[] = [
    { key: 'point', label: 'The forecast', ask: 'Which sentence states the forecast best?', opts: [
      { text: 'Retail sales will be $652.7 billion in September 2027.', good: false,
        why: '“Will be” promises certainty, and one decimal place of a number that may miss by $10 billion is false precision. There is no comparison to give the number meaning.' },
      { text: 'Our HW multiplicative model forecasts 652,660 for 2027-09.', good: false,
        why: 'Method first, jargon, and no units: is 652,660 dollars, millions or billions? (It is $ millions.) The reader has to decode it.' },
      { text: 'We expect U.S. retail sales (not seasonally adjusted) to be about $653 billion in September 2027, 2.8% above September 2026.', good: true,
        why: 'Bottom line first: a number with units, a date, the SA/NSA status, and a like-with-like comparison with the same month a year earlier.' },
    ] },
    { key: 'range', label: 'The range', ask: 'Which sentence explains the 80% range correctly?', opts: [
      { text: 'We are 80% confident that the model is correct.', good: false,
        why: 'The range is about where the outcome may land, not about whether the model is “correct”. Every model is wrong in some way.' },
      { text: 'Sales will be between $626 and $658 billion, about ±$16 billion.', good: false,
        why: 'Two errors. “Will be between” drops the probability: 1 month in 5 should land outside. And “±$16 billion” hides that this range is lopsided: $27 billion below the forecast but only $6 billion above.' },
      { text: 'Our 80% range is $626 to $658 billion: if the next year’s errors look like the last four years’, the outcome should land in it about 8 times out of 10.', good: true,
        why: 'Gives the range, says what 80% means in everyday words, and states the assumption the range rests on.' },
    ] },
    { key: 'track', label: 'The track record', ask: 'Which sentence describes past accuracy best?', opts: [
      { text: 'The model achieved a MASE of 0.49 and an RMSE of 13.6.', good: false,
        why: 'Correct numbers, but a manager cannot use them. Translate metrics into the reader’s units and compare with a rule they understand.' },
      { text: 'Over the past four years this method’s typical miss was $8.8 billion one month ahead and $12.8 billion a year ahead, 35% smaller than using the same month last year.', good: true,
        why: 'Units the reader knows, the horizon spelled out, and a benchmark that shows the model earns its keep.' },
      { text: 'The model is highly accurate and fits the data very well.', good: false,
        why: 'No number, no benchmark, and “fits the data” suggests in-sample fit, which says little about forecast accuracy.' },
    ] },
    { key: 'driver', label: 'A driver', ask: 'From Chapter 4’s car-sales regression: which sentence reads the unemployment coefficient (−0.90) best?', opts: [
      { text: 'Unemployment causes car sales to fall by 0.90.', good: false,
        why: 'A regression on past data shows an association, not a cause, and “0.90” has no units (it is millions of cars a year).' },
      { text: 'In months when unemployment was 1 point higher, car sales ran about 900,000 a year lower (seasonally adjusted annual rate), holding the model’s other drivers fixed.', good: true,
        why: 'Units on both sides, “holding fixed” stated, and worded as a comparison between months, not as a cause.' },
      { text: 'The unemployment coefficient is −0.90 and statistically significant.', good: false,
        why: 'Restates the output without saying what it means. “Significant” is not the same as large or important.' },
    ] },
    { key: 'risk', label: 'The key risk', ask: 'Which sentence names the risk best?', opts: [
      { text: 'Results should be interpreted with caution.', good: false,
        why: 'A caveat that fits every forecast tells the reader nothing. Which way could it go wrong, and why?' },
      { text: 'There is uncertainty due to economic conditions.', good: false,
        why: 'Vague: no direction, no size, no evidence.' },
      { text: 'Key risk: this method has tended to over-forecast, by about $4.9 billion on average, so the outcome may land below our central number.', good: true,
        why: 'One specific risk, its direction and its size, backed by the track record.' },
    ] },
  ];

  let cur = $state(0);
  let pick: (number | null)[] = $state(CLAIMS.map(() => null));
  const claim = $derived(CLAIMS[cur]);
  const nGood = $derived(pick.filter((p, i) => p !== null && CLAIMS[i].opts[p].good).length);
  const nDone = $derived(pick.filter((p) => p !== null).length);
  function choose(j: number) { pick[cur] = j; }
  function key(e: KeyboardEvent) {                  // arrow keys move between claim tabs
    const k = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0;
    if (!k) return; e.preventDefault(); cur = (cur + k + CLAIMS.length) % CLAIMS.length;
    (document.getElementById(`ww-tab-${cur}`) as HTMLElement | null)?.focus();
  }
</script>

<figure class="ww" aria-label="Wording workshop: pick the strongest sentence for each claim">
  <figcaption class="ww-h">
    <span class="ww-k">Wording workshop</span>
    <span class="ww-t">Strong wording gives a number, units, a comparison and an honest caveat</span>
  </figcaption>
  <div class="tabs" role="tablist" aria-label="Claims" tabindex="-1" onkeydown={key}>
    {#each CLAIMS as c, i}
      <button role="tab" id="ww-tab-{i}" aria-selected={cur === i} aria-controls="ww-panel" tabindex={cur === i ? 0 : -1} class:on={cur === i}
        class:good={pick[i] !== null && CLAIMS[i].opts[pick[i]!].good} class:weak={pick[i] !== null && !CLAIMS[i].opts[pick[i]!].good}
        onclick={() => (cur = i)}>
        <span class="n">{pick[i] === null ? i + 1 : CLAIMS[i].opts[pick[i]!].good ? '✓' : '!'}</span>{c.label}
      </button>
    {/each}
  </div>
  <div class="panel" id="ww-panel" role="tabpanel" aria-labelledby="ww-tab-{cur}">
    <fieldset>
      <legend>{claim.ask}</legend>
      {#each claim.opts as o, j}
        <label class="opt" class:picked={pick[cur] === j} class:good={pick[cur] !== null && o.good} class:weak={pick[cur] === j && !o.good}>
          <input type="radio" name="ww-{claim.key}" checked={pick[cur] === j} onchange={() => choose(j)} />
          <span class="ot">“{o.text}”</span>
          {#if pick[cur] !== null}
            <span class="why"><b>{o.good ? 'Strong.' : 'Weak.'}</b> {o.why}</span>
          {/if}
        </label>
      {/each}
    </fieldset>
    <div class="nav">
      <button class="btn btn-ghost btn-sm" disabled={cur === 0} onclick={() => (cur -= 1)}>Previous claim</button>
      <button class="btn btn-sm" disabled={cur === CLAIMS.length - 1} onclick={() => (cur += 1)}>Next claim</button>
    </div>
  </div>
  <div class="para" aria-live="polite">
    <div class="ph"><span>Your paragraph</span><span class="sc">{nGood} of {CLAIMS.length} strong{nDone < CLAIMS.length ? ` · ${CLAIMS.length - nDone} still to choose` : ''}</span></div>
    <p>
      {#each CLAIMS as c, i}
        {#if pick[i] !== null}<span class:weakt={!c.opts[pick[i]!].good}>{c.opts[pick[i]!].text}</span>{' '}{:else}<span class="blank">[{c.label.toLowerCase()}]</span>{' '}{/if}
      {/each}
    </p>
    {#if nGood === CLAIMS.length}<p class="done">Every sentence is decision-ready. Add the trigger (“we will revisit if actual sales fall outside the range two months in a row”) and it is ready to send.</p>{/if}
  </div>
</figure>

<style>
  .ww { margin: 2.4rem 0; border: 1px solid var(--border); border-radius: var(--radius); background: var(--surface); box-shadow: var(--shadow); overflow: hidden; }
  .ww-h { display: flex; flex-direction: column; gap: .2rem; padding: 1rem 1.25rem .6rem; }
  .ww-k { font-size: .8rem; font-weight: 650; color: var(--ch, var(--accent-text)); }
  .ww-t { font-weight: 650; font-size: 1.08rem; color: var(--text); }
  .tabs { display: flex; flex-wrap: wrap; gap: .4rem; padding: 0 1.25rem .8rem; border-bottom: 1px solid var(--border); }
  .tabs button { all: unset; cursor: pointer; display: inline-flex; align-items: center; gap: .4rem; font: 600 .8rem var(--font-ui); padding: .32rem .7rem .32rem .35rem; border-radius: 999px; border: 1px solid var(--border); color: var(--text-2); background: var(--bg); }
  .tabs button.on { border-color: var(--ch, var(--accent)); color: var(--text); }
  .tabs button:focus-visible { outline: 2px solid var(--accent-2); outline-offset: 2px; }
  .n { width: 1.4rem; height: 1.4rem; border-radius: 50%; display: grid; place-items: center; font-size: .72rem; background: var(--bg-2); border: 1px solid var(--border-strong); }
  .tabs button.good .n { color: var(--good); border-color: var(--good); }
  .tabs button.weak .n { color: var(--danger); border-color: var(--danger); }
  .panel { padding: 1rem 1.25rem; }
  fieldset { border: 0; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .55rem; }
  legend { font: 650 .92rem var(--font-ui); color: var(--text); margin-bottom: .5rem; padding: 0; }
  .opt { display: grid; grid-template-columns: auto 1fr; gap: .2rem .6rem; align-items: start; padding: .6rem .75rem; border: 1px solid var(--border); border-radius: 9px; cursor: pointer; background: var(--bg); }
  .opt input { margin-top: .25rem; accent-color: var(--accent); }
  .opt.picked { border-color: var(--border-strong); }
  .opt.good { border-left: 3px solid var(--good); }
  .opt.weak { border-left: 3px solid var(--danger); }
  .ot { font-size: .9rem; color: var(--text); line-height: 1.5; }
  .why { grid-column: 2; font-size: .82rem; color: var(--text-2); line-height: 1.5; }
  .opt.good .why b { color: var(--good); } .opt:not(.good) .why b { color: var(--danger); }
  .nav { display: flex; justify-content: space-between; gap: .6rem; margin-top: .9rem; }
  .para { padding: .9rem 1.25rem 1.1rem; border-top: 1px solid var(--border); background: var(--bg-2); }
  .ph { display: flex; justify-content: space-between; gap: 1rem; flex-wrap: wrap; font-size: .8rem; font-weight: 650; color: var(--muted); }
  .sc { font-variant-numeric: tabular-nums; }
  .para p { margin: .5rem 0 0; font-size: .92rem; line-height: 1.65; color: var(--text); }
  .weakt { text-decoration: underline wavy var(--danger); text-decoration-thickness: 1px; text-underline-offset: 3px; }
  .blank { color: var(--muted); font-style: italic; }
  .done { color: var(--good) !important; font-size: .85rem !important; }
</style>
