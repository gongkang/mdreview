export function containsMermaid(content: string): boolean {
  return /```mermaid[\s\S]*?```/i.test(content);
}

export function containsMath(content: string): boolean {
  return /\$\$[\s\S]+?\$\$/.test(content) || /(^|[^\\])\$[^$\n]+\$/.test(content);
}
