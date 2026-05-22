const remotePattern = /^[a-z][a-z0-9+.-]*:/i;

export function rewriteMarkdownResources(content: string): string {
  return content.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, (match, alt: string, rawUrl: string) => {
    const url = rawUrl.trim();
    if (remotePattern.test(url) || url.startsWith("#")) return match;
    return `![${alt}](mdreview-resource://${url})`;
  });
}
