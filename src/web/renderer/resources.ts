export type ResourceUrlResolver = (src: string) => string;

type HastNode = {
  type?: string;
  tagName?: string;
  properties?: Record<string, unknown>;
  children?: HastNode[];
};

const schemePattern = /^[a-z][a-z0-9+.-]*:/i;
const fileSchemePattern = /^file:/i;
const resourceSchemePattern = /^mdreview-resource:/i;

export function toMdreviewResourceUrl(src: string): string {
  const url = src.trim();
  if (!url || url.startsWith("#") || resourceSchemePattern.test(url)) return src;
  if (fileSchemePattern.test(url)) {
    try {
      const parsed = new URL(url);
      if (parsed.protocol === "file:") return `mdreview-resource://${parsed.pathname}`;
    } catch {
      return src;
    }
  }
  if (schemePattern.test(url)) return src;
  return `mdreview-resource://${url}`;
}

export function createImageResourcePlugin(resourceUrlResolver: ResourceUrlResolver) {
  return function imageResourcePlugin() {
    return function transform(tree: HastNode) {
      rewriteImageSources(tree, resourceUrlResolver);
    };
  };
}

function rewriteImageSources(node: HastNode, resourceUrlResolver: ResourceUrlResolver) {
  if (node.type === "element" && node.tagName === "img" && typeof node.properties?.src === "string") {
    node.properties = {
      ...node.properties,
      src: resourceUrlResolver(node.properties.src)
    };
  }
  for (const child of node.children ?? []) rewriteImageSources(child, resourceUrlResolver);
}

export function rewriteMarkdownResources(content: string): string {
  return content.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, (match, alt: string, rawUrl: string) => {
    const url = rawUrl.trim();
    const rewritten = toMdreviewResourceUrl(url);
    if (rewritten === url) return match;
    return `![${alt}](${rewritten})`;
  });
}
