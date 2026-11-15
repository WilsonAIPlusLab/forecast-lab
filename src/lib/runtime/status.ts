// Tiny pub/sub shared by every island on the page (one module instance per page bundle).
export type Lang = 'r' | 'py';
export interface RuntimeState { state: 'idle' | 'loading' | 'ready' | 'busy' | 'error'; message: string; progress: number; }
const states: Record<Lang, RuntimeState> = {
  r: { state: 'idle', message: 'R not started', progress: 0 },
  py: { state: 'idle', message: 'Python not started', progress: 0 },
};
const subs = new Set<(l: Lang, s: RuntimeState) => void>();
export function setStatus(l: Lang, s: Partial<RuntimeState>) {
  states[l] = { ...states[l], ...s };
  subs.forEach((f) => f(l, states[l]));
  window.dispatchEvent(new CustomEvent('runtime-status', { detail: { lang: l, ...states[l] } }));
}
export function getStatus(l: Lang) { return states[l]; }
export function onStatus(f: (l: Lang, s: RuntimeState) => void) { subs.add(f); f('r', states.r); f('py', states.py); return () => subs.delete(f); }

export const BASE = (import.meta.env.BASE_URL || '/').replace(/\/?$/, '/');
export const prefLang = {
  get(): Lang { try { return (localStorage.getItem('fl-lang') as Lang) || 'r'; } catch { return 'r'; } },
  set(l: Lang) { try { localStorage.setItem('fl-lang', l); } catch {} window.dispatchEvent(new CustomEvent('lang-change', { detail: l })); },
};
