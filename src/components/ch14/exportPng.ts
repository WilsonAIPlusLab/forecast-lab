// Studio utilities: slide-ready PNG export (title + chart + source), clipboard, and direct-label de-overlap.
import { css } from '../../lib/viz/theme';

const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

/** Wrap text into lines of at most `max` characters (for titles in the exported PNG). */
function wrap(s: string, max: number) {
  const out: string[] = []; let line = '';
  for (const w of s.split(' ')) { if ((line + ' ' + w).trim().length > max && line) { out.push(line); line = w; } else line = (line + ' ' + w).trim(); }
  if (line) out.push(line); return out;
}

/** Download the chart SVG as a 2x PNG with a title, subtitle and source line baked in, ready for a slide deck. */
export async function downloadPng(svg: SVGSVGElement, o: { title: string; subtitle: string; source: string; name: string }) {
  const W = svg.clientWidth || +(svg.getAttribute('width') || 800), H = svg.clientHeight || +(svg.getAttribute('height') || 400);
  const clone = svg.cloneNode(true) as SVGSVGElement;
  const src = svg.querySelectorAll('text'), dst = clone.querySelectorAll('text');
  src.forEach((t, i) => { const cs = getComputedStyle(t); dst[i].setAttribute('fill', cs.fill); dst[i].setAttribute('font-family', 'Inter, Arial, sans-serif'); dst[i].setAttribute('font-size', cs.fontSize); });
  clone.setAttribute('width', String(W)); clone.setAttribute('height', String(H)); clone.setAttribute('x', '0'); clone.setAttribute('y', '0');
  clone.style.color = getComputedStyle(svg).color;
  const pad = 24, tl = wrap(o.title, Math.round(W / 10.5)), sl = wrap(o.subtitle, Math.round(W / 7));
  const top = 22 + tl.length * 24 + sl.length * 18 + 14, bottom = 40;
  const tW = W + 2 * pad, tH = top + H + bottom;
  const font = 'Inter, Arial, sans-serif';
  const txt = (lines: string[], y0: number, dy: number, size: number, weight: number, fill: string) =>
    lines.map((l, i) => `<text x="${pad}" y="${y0 + i * dy}" font-family="${font}" font-size="${size}" font-weight="${weight}" fill="${fill}">${esc(l)}</text>`).join('');
  const xml = `<svg xmlns="http://www.w3.org/2000/svg" width="${tW}" height="${tH}" viewBox="0 0 ${tW} ${tH}">` +
    `<rect width="100%" height="100%" fill="${css('--surface')}"/>` +
    txt(tl, 34, 24, 19, 700, css('--text')) + txt(sl, 34 + tl.length * 24 + 2, 18, 13, 400, css('--text-2')) +
    `<g transform="translate(${pad},${top})">${new XMLSerializer().serializeToString(clone)}</g>` +
    txt([o.source], top + H + 26, 0, 11, 400, css('--muted')) + `</svg>`;
  const url = URL.createObjectURL(new Blob([xml], { type: 'image/svg+xml' }));
  const img = new Image(); img.src = url; await img.decode();
  const c = document.createElement('canvas'); c.width = tW * 2; c.height = tH * 2;
  const g = c.getContext('2d')!; g.scale(2, 2); g.drawImage(img, 0, 0);
  URL.revokeObjectURL(url);
  const a = document.createElement('a'); a.download = `${o.name}.png`; a.href = c.toDataURL('image/png'); a.click();
}

/** Copy text to the clipboard, with a fallback for older browsers and non-secure contexts. */
export async function copyText(s: string): Promise<boolean> {
  try { await navigator.clipboard.writeText(s); return true; } catch {}
  try {
    const ta = document.createElement('textarea'); ta.value = s; ta.setAttribute('readonly', ''); ta.style.position = 'fixed'; ta.style.opacity = '0';
    document.body.append(ta); ta.select(); const ok = document.execCommand('copy'); ta.remove(); return ok;
  } catch { return false; }
}

/**
 * Nudge direct labels apart vertically so they never overlap.
 * items carry a data value `v`; domain/innerHeight describe the y scale (linear, top = d1). Returns adjusted data values.
 */
export function dodge<T extends { v: number }>(items: T[], domain: [number, number], innerHeight: number, gap = 15): (T & { vy: number })[] {
  const [d0, d1] = domain, toPx = (v: number) => (1 - (v - d0) / (d1 - d0)) * innerHeight, toV = (px: number) => d0 + (1 - px / innerHeight) * (d1 - d0);
  const s = items.map((it) => ({ it, px: toPx(it.v) })).sort((a, b) => a.px - b.px);
  for (let i = 1; i < s.length; i++) if (s[i].px - s[i - 1].px < gap) s[i].px = s[i - 1].px + gap;
  if (s.length && s[s.length - 1].px > innerHeight) { // pushed off the bottom: stack upward from the bottom edge instead
    s[s.length - 1].px = innerHeight;
    for (let i = s.length - 2; i >= 0; i--) s[i].px = Math.min(s[i].px, s[i + 1].px - gap);
  }
  return s.map(({ it, px }) => ({ ...it, vy: toV(px) }));
}
