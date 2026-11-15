// CodeMirror 6 editor with R/Python modes, theme tied to CSS variables, and step highlighting.
import { EditorState, StateEffect, StateField, Compartment, RangeSetBuilder } from '@codemirror/state';
import { EditorView, Decoration, keymap, lineNumbers, highlightActiveLine, drawSelection, type DecorationSet } from '@codemirror/view';
import { defaultKeymap, history, historyKeymap, indentWithTab } from '@codemirror/commands';
import { StreamLanguage, syntaxHighlighting, HighlightStyle, bracketMatching, indentOnInput } from '@codemirror/language';
import { r as rMode } from '@codemirror/legacy-modes/mode/r';
import { python } from '@codemirror/lang-python';
import { tags as t } from '@lezer/highlight';

const hl = HighlightStyle.define([
  { tag: [t.keyword, t.controlKeyword, t.operatorKeyword], color: 'var(--syn-kw)', fontWeight: '600' },
  { tag: [t.string, t.special(t.string)], color: 'var(--syn-str)' },
  { tag: [t.number, t.bool, t.atom], color: 'var(--syn-num)' },
  { tag: t.comment, color: 'var(--syn-com)', fontStyle: 'italic' },
  { tag: [t.function(t.variableName), t.function(t.propertyName)], color: 'var(--syn-fn)' },
  { tag: [t.variableName, t.name], color: 'var(--text)' },
  { tag: [t.operator, t.punctuation], color: 'var(--syn-op)' },
  { tag: [t.definition(t.variableName)], color: 'var(--syn-def)' },
  { tag: t.propertyName, color: 'var(--syn-prop)' },
]);

const theme = EditorView.theme({
  '&': { backgroundColor: 'transparent', color: 'var(--text)', fontSize: '13.6px' },
  '.cm-content': { fontFamily: 'var(--font-mono)', fontVariantLigatures: 'none', padding: '14px 0', caretColor: 'var(--accent-2)' },
  '.cm-scroller': { fontFamily: 'var(--font-mono)', lineHeight: '1.65' },
  '.cm-gutters': { backgroundColor: 'transparent', border: 'none', color: 'var(--muted)', opacity: '.6' },
  '.cm-lineNumbers .cm-gutterElement': { padding: '0 10px 0 14px', minWidth: '34px' },
  '.cm-activeLine': { backgroundColor: 'rgba(124,92,255,.06)' },
  '.cm-selectionBackground, &.cm-focused .cm-selectionBackground, ::selection': { backgroundColor: 'rgba(124,92,255,.3) !important' },
  '&.cm-focused': { outline: 'none' },
  '.cm-cursor': { borderLeftColor: 'var(--accent-2)', borderLeftWidth: '2px' },
  '.cm-step-line': { backgroundColor: 'rgba(34,211,238,.11)', boxShadow: 'inset 3px 0 0 var(--accent-2)' },
  '.cm-step-done': { opacity: '.55' },
  '.cm-matchingBracket': { backgroundColor: 'rgba(124,92,255,.25)', outline: 'none' },
});

const setStep = StateEffect.define<{ start: number; end: number; doneUntil: number } | null>();
const stepField = StateField.define<DecorationSet>({
  create: () => Decoration.none,
  update(deco, tr) {
    deco = deco.map(tr.changes);
    for (const e of tr.effects) if (e.is(setStep)) {
      if (!e.value) return Decoration.none;
      const b = new RangeSetBuilder<Decoration>();
      const doc = tr.state.doc;
      for (let i = 1; i <= doc.lines; i++) {
        const line = doc.line(i);
        if (i >= e.value.start && i <= e.value.end) b.add(line.from, line.from, Decoration.line({ class: 'cm-step-line' }));
        else if (i < e.value.doneUntil) b.add(line.from, line.from, Decoration.line({ class: 'cm-step-done' }));
      }
      return b.finish();
    }
    return deco;
  },
  provide: (f) => EditorView.decorations.from(f),
});

export interface EditorHandle {
  view: EditorView;
  get(): string;
  set(doc: string): void;
  setLang(l: 'r' | 'py'): void;
  highlight(start: number, end: number, doneUntil?: number): void;
  clear(): void;
  setReadOnly(ro: boolean): void;
  destroy(): void;
}

export function createEditor(parent: HTMLElement, opts: { doc: string; lang: 'r' | 'py'; onRun?: () => void; onChange?: (s: string) => void }): EditorHandle {
  const langC = new Compartment(), roC = new Compartment();
  const langExt = (l: 'r' | 'py') => (l === 'r' ? StreamLanguage.define(rMode) : python());
  const view = new EditorView({
    parent,
    state: EditorState.create({
      doc: opts.doc,
      extensions: [
        lineNumbers(), history(), drawSelection(), highlightActiveLine(), bracketMatching(), indentOnInput(),
        keymap.of([
          { key: 'Mod-Enter', run: () => { opts.onRun?.(); return true; } },
          { key: 'Shift-Enter', run: () => { opts.onRun?.(); return true; } },
          indentWithTab, ...defaultKeymap, ...historyKeymap,
        ]),
        langC.of(langExt(opts.lang)), roC.of(EditorState.readOnly.of(false)),
        syntaxHighlighting(hl), theme, stepField, EditorView.lineWrapping,
        EditorView.updateListener.of((u) => { if (u.docChanged) opts.onChange?.(u.state.doc.toString()); }),
        EditorView.contentAttributes.of({ 'aria-label': 'Code editor — press Ctrl+Enter to run' }),
      ],
    }),
  });
  return {
    view,
    get: () => view.state.doc.toString(),
    set: (doc) => view.dispatch({ changes: { from: 0, to: view.state.doc.length, insert: doc } }),
    setLang: (l) => view.dispatch({ effects: langC.reconfigure(langExt(l)) }),
    highlight: (start, end, doneUntil = start) => {
      view.dispatch({ effects: setStep.of({ start, end, doneUntil }) });
      const ln = Math.min(start, view.state.doc.lines);
      view.dispatch({ effects: EditorView.scrollIntoView(view.state.doc.line(ln).from, { y: 'nearest' }) });
    },
    clear: () => view.dispatch({ effects: setStep.of(null) }),
    setReadOnly: (ro) => view.dispatch({ effects: roC.reconfigure(EditorState.readOnly.of(ro)) }),
    destroy: () => view.destroy(),
  };
}

/** Split authored code into clean code + step notes. Lines starting with `#|` are notes for the code below them. */
export function parseAuthored(src: string): { code: string; steps: { start: number; end: number; note: string }[] } {
  const raw = src.replace(/\r\n/g, '\n').replace(/^\n+|\s+$/g, '').split('\n');
  const out: string[] = []; const steps: { start: number; end: number; note: string }[] = [];
  let note: string[] | null = null; let cur: { start: number; end: number; note: string } | null = null;
  for (const line of raw) {
    const m = line.match(/^\s*#\|\s?(.*)$/);
    if (m) { if (note === null) note = []; note.push(m[1]); continue; }
    if (note !== null) {
      if (cur) steps.push(cur);
      cur = { start: out.length + 1, end: out.length + 1, note: note.join('\n') }; note = null;
    }
    out.push(line);
    if (cur && line.trim() !== '') cur.end = out.length;
  }
  if (cur) steps.push(cur);
  return { code: out.join('\n'), steps };
}
