// Minimal inline markdown for step notes, Predict text and captions:
// `code`, **bold**, *italic*, [link](url), bullet lists, paragraphs, $math$ (KaTeX, rendered lazily),
// plus a safe subset of inline HTML (<b> <strong> <em> <i> <sup> <sub> <br> <code>).
import { BASE } from './runtime/status';

const fixHref = (h: string) => (h.startsWith('/') && !h.startsWith('//') && !h.startsWith(BASE) ? BASE + h.slice(1) : h);
const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const SAFE = /&lt;(\/?)(b|strong|em|i|sup|sub|br|code)\s*\/?&gt;/g;

function inline(h: string) {
  // protect code spans and math first so their contents are not formatted
  const store: string[] = [];
  const keep = (html: string) => `\u0000${store.push(html) - 1}\u0000`;
  h = h.replace(/`([^`]+)`/g, (_m, c) => keep(`<code>${c}</code>`));
  // pandoc-style inline math: $x$ with no space just inside the dollars, and no digit right after the closing $
  h = h.replace(/(^|[^\\\w$])\$(?=\S)([^$\n]*?[^\s\\$])\$(?!\d)/g, (_m, pre, tex) => pre + keep(`<span class="km" data-tex="${tex.replace(/"/g, '&quot;')}">${tex}</span>`));
  h = h.replace(/\\\$/g, '$');
  h = h
    .replace(SAFE, '<$1$2>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/(^|[^*\w])\*([^*\n]+)\*/g, '$1<em>$2</em>')
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_m, t, u) => `<a href="${fixHref(u)}">${t}</a>`);
  return h.replace(/\u0000(\d+)\u0000/g, (_m, i) => store[+i]);
}

export function md(s: string) {
  const blocks = esc(s.trim()).split(/\n{2,}/);
  return blocks
    .map((b) => {
      const lines = b.split('\n');
      let html = '', para: string[] = [], list: string[] = [];
      const flushP = () => { if (para.length) { html += `<p>${inline(para.join(' '))}</p>`; para = []; } };
      const flushL = () => { if (list.length) { html += `<ul>${list.map((l) => `<li>${inline(l)}</li>`).join('')}</ul>`; list = []; } };
      for (const l of lines) {
        const m = l.match(/^\s*[-•]\s+(.*)$/);
        if (m) { flushP(); list.push(m[1]); } else { flushL(); para.push(l); }
      }
      flushP(); flushL();
      return html;
    })
    .join('');
}

/** Render any pending `.km` math spans on the page with KaTeX (loaded on first need). */
let katexP: Promise<any> | null = null;
export function watchMath() {
  if (typeof window === 'undefined' || (window as any).__kmWatch) return;
  (window as any).__kmWatch = true;
  const run = async () => {
    const els = document.querySelectorAll<HTMLElement>('span.km:not([data-done])');
    if (!els.length) return;
    katexP ??= import('katex').then((m) => m.default ?? m);
    const katex = await katexP;
    els.forEach((el) => {
      try { katex.render(el.dataset.tex || '', el, { throwOnError: false }); } catch {}
      el.dataset.done = '1';
    });
  };
  new MutationObserver(() => run()).observe(document.body, { childList: true, subtree: true });
  run();
}
