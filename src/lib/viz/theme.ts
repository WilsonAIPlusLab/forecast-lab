// Shared theming helpers for hand-built Observable Plot explorables.
export const css = (v: string) => (typeof window === 'undefined' ? '#888' : getComputedStyle(document.documentElement).getPropertyValue(v).trim() || '#888');
export const C = {
  get history() { return css('--c-history'); },
  get forecast() { return css('--c-forecast'); },
  get actual() { return css('--c-actual'); },
  get fitted() { return css('--c-fitted'); },
  get muted() { return css('--muted'); },
  get border() { return css('--border'); },
  get borderStrong() { return css('--border-strong'); },
  get text() { return css('--text'); },
  get text2() { return css('--text-2'); },
  get surface() { return css('--surface'); },
  get good() { return css('--good'); },
  get danger() { return css('--danger'); },
  get s() { return ['--c-s1', '--c-s2', '--c-s3', '--c-s4', '--c-s5', '--c-s6'].map(css); },
};
export const plotStyle = () => ({ background: 'transparent', color: css('--muted'), fontSize: '12px', fontFamily: 'var(--font-ui)', overflow: 'visible' });
export const fmt = (v: number) => (Math.abs(v) >= 1e4 ? v.toLocaleString(undefined, { maximumFractionDigits: 0 }) : +v.toPrecision(4) + '');

/** Re-run fn when the theme changes or the element resizes; returns cleanup. */
export function watchLayout(el: HTMLElement, fn: () => void) {
  let w = el.clientWidth;
  const ro = new ResizeObserver(() => { if (Math.abs(el.clientWidth - w) > 20) { w = el.clientWidth; fn(); } });
  ro.observe(el);
  window.addEventListener('theme-change', fn);
  return () => { ro.disconnect(); window.removeEventListener('theme-change', fn); };
}
