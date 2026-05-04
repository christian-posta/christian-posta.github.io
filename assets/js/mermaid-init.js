/**
 * Turn Jekyll/kramdown ```mermaid fences into rendered diagrams.
 * GitHub Pages serves static HTML; Mermaid is not applied automatically (unlike github.com markdown previews).
 */
(async function () {
  const blocks = document.querySelectorAll('pre > code.language-mermaid');
  if (!blocks.length) return;

  const { default: mermaid } = await import(
    'https://cdn.jsdelivr.net/npm/mermaid@11/+esm'
  );

  mermaid.initialize({ startOnLoad: false, theme: 'neutral' });

  const nodes = [];
  blocks.forEach((code) => {
    const pre = code.parentElement;
    if (!pre || pre.tagName !== 'PRE' || !pre.parentNode) return;
    const graph = code.textContent.trim();
    if (!graph) return;
    const el = document.createElement('div');
    el.className = 'mermaid';
    el.textContent = graph;
    pre.parentNode.replaceChild(el, pre);
    nodes.push(el);
  });

  if (nodes.length) await mermaid.run({ nodes });
})();
