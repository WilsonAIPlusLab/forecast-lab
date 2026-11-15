// @ts-check
import { defineConfig } from 'astro/config';
import mdx from '@astrojs/mdx';
import svelte from '@astrojs/svelte';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';

const BASE = (process.env.BASE || '/').replace(/\/?$/, '/');
// Prefix the deploy base path (e.g. /forecast-lab/) to root-relative links written in chapter text.
function rehypeBaseLinks() {
  const walk = (n) => {
    if (n.type === 'element' && n.tagName === 'a' && typeof n.properties?.href === 'string') {
      const h = n.properties.href;
      if (BASE !== '/' && h.startsWith('/') && !h.startsWith('//') && !h.startsWith(BASE)) n.properties.href = BASE + h.slice(1);
    }
    (n.children || []).forEach(walk);
  };
  return (tree) => walk(tree);
}


// Turn plain "Chapter N" mentions in chapter prose into links to that chapter (keeps pages well connected).
const SLUGS = ['first-forecast', 'time-series-data', 'decomposition', 'benchmarks', 'regression', 'nonlinear-regression',
  'exponential-smoothing', 'arima', 'dynamic-regression', 'recession-probability', 'var', 'uncertainty',
  'random-forests', 'boosting-shap', 'nowcasting', 'forecast-studio'];  // index = chapter number (keep in sync with src/lib/chapters.ts)
function rehypeChapterLinks() {
  const SKIP = new Set(['a', 'h1', 'h2', 'h3', 'h4', 'code', 'pre', 'script', 'style', 'svg', 'math', 'button', 'summary']);
  const RE = /\bChapter (\d{1,2})\b/g;
  return (tree, file) => {
    const path = String(file?.history?.[0] || file?.path || '').replace(/\\/g, '/');
    const self = (path.match(/chapters\/([a-z-]+)\.mdx$/) || [])[1];
    const walk = (n, skip) => {
      if (!n.children) return;
      const out = [];
      for (const c of n.children) {
        const cls = c.properties?.className;
        const isKatex = Array.isArray(cls) && cls.some((x) => String(x).startsWith('katex'));
        const s2 = skip || (c.type === 'element' && (SKIP.has(c.tagName) || isKatex)) || (c.type === 'mdxJsxTextElement' && c.name === 'a');
        if (c.type === 'text' && !skip && RE.test(c.value)) {
          RE.lastIndex = 0;
          let last = 0, m;
          while ((m = RE.exec(c.value))) {
            const num = +m[1], slug = SLUGS[num];
            if (!slug || slug === self) continue;
            if (m.index > last) out.push({ type: 'text', value: c.value.slice(last, m.index) });
            out.push({ type: 'element', tagName: 'a', properties: { href: `${BASE}chapters/${slug}/`, className: ['xref'] }, children: [{ type: 'text', value: m[0] }] });
            last = m.index + m[0].length;
          }
          if (last < c.value.length) out.push({ type: 'text', value: c.value.slice(last) });
          continue;
        }
        walk(c, s2);
        out.push(c);
      }
      n.children = out;
    };
    walk(tree, false);
  };
}

// For GitHub Pages set SITE and BASE, e.g. SITE=https://user.github.io BASE=/forecast-lab
export default defineConfig({
  site: process.env.SITE || 'http://localhost:4321',
  base: process.env.BASE || '/',
  trailingSlash: 'ignore',
  markdown: { remarkPlugins: [remarkMath], rehypePlugins: [rehypeKatex, rehypeChapterLinks, rehypeBaseLinks] },
  integrations: [mdx(), svelte()],
  vite: { optimizeDeps: { exclude: ['webr', 'pyodide'] } },
});
