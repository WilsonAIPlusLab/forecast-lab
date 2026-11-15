// Paste/run in the browser on a chapter page: runs every CodeLab (R, then Python if present) and records results in window.__audit.
// Poll window.__audit.done / window.__audit.results.
(async () => {
  const A = (window.__audit = { done: false, results: [], started: Date.now() });
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const labs = [...document.querySelectorAll('section.lab')];
  for (const [i, lab] of labs.entries()) {
    const title = lab.querySelector('.lab-title span:nth-child(2)')?.textContent?.trim();
    const tabs = [...lab.querySelectorAll('.lab-tabs button')].map((b) => b.textContent.trim());
    const isEx = !!lab.querySelector('.lab-goal span')?.textContent?.includes('task');
    for (const lang of tabs) {
      lab.querySelector(`.lab-tabs button:nth-child(${tabs.indexOf(lang) + 1})`)?.click();
      await sleep(400);
      if (isEx) {
        const sol = [...lab.querySelectorAll('.lab-bar button')].find((b) => b.textContent.includes('Show solution'));
        // reveal a hint to unlock solution, then load solution
        [...lab.querySelectorAll('.lab-bar button')].find((b) => b.textContent.startsWith('Hint'))?.click();
        await sleep(200);
        sol?.click();
        await sleep(300);
      }
      const t0 = performance.now();
      lab.querySelector('.lab-bar .btn-primary')?.click();
      await sleep(500);
      // wait until running finishes (Stop button disappears), max 180s
      let waited = 0;
      while (lab.querySelector('.stopbtn') && waited < 180000) { await sleep(500); waited += 500; }
      await sleep(800);
      const out = lab.querySelector('.console pre')?.innerText || '';
      const err = lab.querySelector('.console.err') ? out.split('\n').filter((l) => /Error|error|Traceback|Exception/.test(l)).slice(0, 4).join(' | ') : '';
      const check = lab.querySelector('.viz-check')?.innerText?.replace(/\s+/g, ' ').slice(0, 80) || '';
      A.results.push({ i, title, lang, s: +((performance.now() - t0) / 1000).toFixed(1), timedOut: waited >= 180000, viz: lab.querySelectorAll('.lab-viz').length, imgs: lab.querySelectorAll('.lab-img').length, err, check, exercise: isEx });
    }
  }
  A.done = true;
  A.total = ((Date.now() - A.started) / 1000).toFixed(0);
})();
