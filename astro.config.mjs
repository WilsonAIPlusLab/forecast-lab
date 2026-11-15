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

// For GitHub Pages set SITE and BASE, e.g. SITE=https://user.github.io BASE=/forecast-lab
export default defineConfig({
  site: process.env.SITE || 'http://localhost:4321',
  base: process.env.BASE || '/',
  trailingSlash: 'ignore',
  markdown: { remarkPlugins: [remarkMath], rehypePlugins: [rehypeKatex, rehypeBaseLinks] },
  integrations: [mdx(), svelte()],
  vite: { optimizeDeps: { exclude: ['webr', 'pyodide'] } },
});
