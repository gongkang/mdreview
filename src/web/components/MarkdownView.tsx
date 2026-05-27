import { isValidElement, useEffect, useMemo, useState } from "react";
import type { MouseEvent, ReactNode } from "react";
import ReactMarkdown, { defaultUrlTransform } from "react-markdown";
import rehypeHighlight from "rehype-highlight";
import rehypeRaw from "rehype-raw";
import rehypeSanitize from "rehype-sanitize";
import remarkGfm from "remark-gfm";
import type { PluggableList } from "unified";
import { containsMath, containsMermaid } from "../markdown/detect";
import type { OutlineItem } from "../markdown/outline";
import { markdownSanitizeSchema } from "../markdown/sanitize";
import { createImageResourcePlugin, type ResourceUrlResolver } from "../renderer/resources";
import "highlight.js/styles/github.css";
import "katex/dist/katex.min.css";

type DynamicPlugins = {
  remarkMath?: PluggableList[number];
  rehypeKatex?: PluggableList[number];
};

type MarkdownViewProps = {
  content: string;
  onOutline: (items: OutlineItem[]) => void;
  enableCodeCopy?: boolean;
  documentPath?: string;
  onDocumentLink?: (target: DocumentLinkTarget) => void;
  resourceUrlResolver?: ResourceUrlResolver;
};

export type DocumentLinkTarget = {
  path: string;
  hash?: string;
};

type HastNode = {
  value?: unknown;
  children?: HastNode[];
};

type CodeFence = {
  marker: "`" | "~";
  length: number;
};

function slugify(value: string): string {
  const slug = value
    .trim()
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, "-")
    .replace(/^-+|-+$/g, "");
  return slug || "section";
}

function uniqueSlug(value: string, used: Map<string, number>): string {
  const base = slugify(value);
  const count = used.get(base) ?? 0;
  used.set(base, count + 1);
  return count === 0 ? base : `${base}-${count}`;
}

export function outlineFromMarkdown(content: string): OutlineItem[] {
  const used = new Map<string, number>();
  const outline: OutlineItem[] = [];
  let activeFence: CodeFence | null = null;

  for (const line of content.split("\n")) {
    if (activeFence) {
      if (closesFence(line, activeFence)) activeFence = null;
      continue;
    }

    const fence = codeFenceFromLine(line);
    if (fence) {
      activeFence = fence;
      continue;
    }

    const match = /^(#{1,6})\s+(.+)$/.exec(line);
    if (match) {
      outline.push({ depth: match[1].length, text: match[2], id: uniqueSlug(match[2], used) });
    }
  }

  return outline;
}

function codeFenceFromLine(line: string): CodeFence | null {
  const match = /^ {0,3}(`{3,}|~{3,})/.exec(line);
  if (!match) return null;
  return { marker: match[1][0] as "`" | "~", length: match[1].length };
}

function closesFence(line: string, fence: CodeFence): boolean {
  const pattern = new RegExp(`^ {0,3}\\${fence.marker}{${fence.length},}\\s*$`);
  return pattern.test(line);
}

function textFromReactNode(node: ReactNode): string {
  if (node === null || node === undefined || typeof node === "boolean") return "";
  if (typeof node === "string" || typeof node === "number" || typeof node === "bigint") return String(node);
  if (Array.isArray(node)) return node.map(textFromReactNode).join("");
  if (isValidElement<{ children?: ReactNode }>(node)) return textFromReactNode(node.props.children);
  return "";
}

function MermaidBlock({ code }: { code: string }) {
  const [svg, setSvg] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    import("mermaid")
      .then(async ({ default: mermaid }) => {
        mermaid.initialize({ startOnLoad: false, securityLevel: "strict" });
        const result = await mermaid.render(`mermaid-${crypto.randomUUID()}`, code);
        if (!cancelled) setSvg(result.svg);
      })
      .catch((reason) => {
        if (!cancelled) setError(reason instanceof Error ? reason.message : String(reason));
      });
    return () => {
      cancelled = true;
    };
  }, [code]);

  if (error) return <pre className="render-error">{code}</pre>;
  if (!svg) return <pre className="render-pending">{code}</pre>;
  return <div className="mermaid-output" dangerouslySetInnerHTML={{ __html: svg }} />;
}

function textFromNode(node: HastNode | undefined): string {
  if (!node) return "";
  if (typeof node.value === "string") return node.value;
  return node.children?.map(textFromNode).join("") ?? "";
}

function copyWithFallback(value: string): Promise<void> {
  if (navigator.clipboard?.writeText) {
    return navigator.clipboard.writeText(value);
  }

  const textArea = document.createElement("textarea");
  textArea.value = value;
  textArea.setAttribute("readonly", "");
  textArea.style.position = "fixed";
  textArea.style.top = "-1000px";
  document.body.appendChild(textArea);
  textArea.select();
  document.execCommand("copy");
  textArea.remove();
  return Promise.resolve();
}

function markdownUrlTransform(value: string): string {
  if (/^mdreview-resource:/i.test(value)) return value;
  return defaultUrlTransform(value);
}

function isMermaidCodeNode(node: ReactNode): boolean {
  if (Array.isArray(node)) return node.some(isMermaidCodeNode);
  if (!isValidElement<{ className?: unknown }>(node)) return false;
  return typeof node.props.className === "string" && /language-mermaid/i.test(node.props.className);
}

const markdownDocumentPattern = /\.(md|markdown|mdown|mkd|mkdn)$/i;
const linkSchemePattern = /^[a-z][a-z0-9+.-]*:/i;

function decodeLinkPart(value: string): string {
  try {
    return decodeURI(value);
  } catch {
    return value;
  }
}

function decodeHash(value: string): string {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}

function splitHref(value: string): { path: string; hash?: string } {
  const hashIndex = value.indexOf("#");
  const beforeHash = hashIndex >= 0 ? value.slice(0, hashIndex) : value;
  const rawHash = hashIndex >= 0 ? value.slice(hashIndex + 1) : "";
  const queryIndex = beforeHash.indexOf("?");
  return {
    path: queryIndex >= 0 ? beforeHash.slice(0, queryIndex) : beforeHash,
    hash: rawHash ? decodeHash(rawHash) : undefined
  };
}

function dirname(value: string): string {
  const normalized = value.replace(/\\/g, "/");
  const index = normalized.lastIndexOf("/");
  if (index < 0) return "";
  if (index === 0) return "/";
  return normalized.slice(0, index);
}

function joinPath(base: string, target: string): string {
  if (!base) return target;
  if (base === "/") return `/${target}`;
  return `${base}/${target}`;
}

function normalizePath(value: string): string {
  const normalized = value.replace(/\\/g, "/");
  const absolute = normalized.startsWith("/");
  const parts: string[] = [];

  for (const part of normalized.split("/")) {
    if (!part || part === ".") continue;
    if (part === "..") {
      if (parts.length > 0 && parts[parts.length - 1] !== "..") {
        parts.pop();
      } else if (!absolute) {
        parts.push(part);
      }
      continue;
    }
    parts.push(part);
  }

  const path = parts.join("/");
  if (absolute) return `/${path}`;
  return path || ".";
}

function isMarkdownDocumentPath(value: string): boolean {
  return markdownDocumentPattern.test(value);
}

export function resolveDocumentLink(href: string, currentDocumentPath: string): DocumentLinkTarget | null {
  const trimmed = href.trim();
  if (!trimmed || trimmed.startsWith("#")) return null;

  if (/^file:/i.test(trimmed)) {
    try {
      const url = new URL(trimmed);
      const path = decodeLinkPart(url.pathname);
      if (!isMarkdownDocumentPath(path)) return null;
      return { path: normalizePath(path), hash: url.hash ? decodeHash(url.hash.slice(1)) : undefined };
    } catch {
      return null;
    }
  }

  if (linkSchemePattern.test(trimmed)) return null;

  const { path, hash } = splitHref(trimmed);
  const decodedPath = decodeLinkPart(path);
  if (!decodedPath || !isMarkdownDocumentPath(decodedPath)) return null;

  if (decodedPath.startsWith("/")) {
    const targetPath = currentDocumentPath.startsWith("/") ? decodedPath : decodedPath.replace(/^\/+/, "");
    return { path: normalizePath(targetPath), hash };
  }

  return { path: normalizePath(joinPath(dirname(currentDocumentPath), decodedPath)), hash };
}

function CopyableCodeBlock({ className, code, children }: { className?: string; code: string; children: ReactNode }) {
  const [copyState, setCopyState] = useState<"idle" | "copied" | "failed">("idle");
  const isCopied = copyState === "copied";
  const isFailed = copyState === "failed";
  const label = isCopied ? "已复制" : isFailed ? "复制失败" : "复制";
  const accessibilityLabel = isCopied ? "已复制代码" : isFailed ? "复制代码失败" : "复制代码";

  async function copy() {
    try {
      await copyWithFallback(code);
      setCopyState("copied");
      window.setTimeout(() => setCopyState("idle"), 1400);
    } catch {
      setCopyState("failed");
      window.setTimeout(() => setCopyState("idle"), 1800);
    }
  }

  return (
    <div className="code-block">
      <div className="code-block-toolbar">
        <button type="button" className="code-copy-button" aria-label={accessibilityLabel} onClick={copy}>
          {label}
        </button>
      </div>
      <pre>
        <code className={className}>{children}</code>
      </pre>
    </div>
  );
}

export function MarkdownView({
  content,
  onOutline,
  enableCodeCopy = false,
  documentPath,
  onDocumentLink,
  resourceUrlResolver
}: MarkdownViewProps) {
  const outline = useMemo(() => outlineFromMarkdown(content), [content]);
  const [dynamicPlugins, setDynamicPlugins] = useState<DynamicPlugins>({});
  const headingSlugs = new Map<string, number>();
  const headingID = (children: ReactNode) => uniqueSlug(textFromReactNode(children), headingSlugs);
  const imageResourcePlugin = useMemo(
    () => (resourceUrlResolver ? createImageResourcePlugin(resourceUrlResolver) : null),
    [resourceUrlResolver]
  );

  useEffect(() => {
    onOutline(outline);
  }, [onOutline, outline]);

  useEffect(() => {
    let cancelled = false;
    if (!containsMath(content)) {
      setDynamicPlugins({});
      return;
    }
    Promise.all([import("remark-math"), import("rehype-katex")]).then(([remarkMath, rehypeKatex]) => {
      if (!cancelled) setDynamicPlugins({ remarkMath: remarkMath.default, rehypeKatex: rehypeKatex.default });
    });
    return () => {
      cancelled = true;
    };
  }, [content]);

  const remarkPlugins: PluggableList = dynamicPlugins.remarkMath ? [remarkGfm, dynamicPlugins.remarkMath] : [remarkGfm];
  const rehypePlugins: PluggableList = [
    rehypeRaw,
    ...(imageResourcePlugin ? [imageResourcePlugin] : []),
    [rehypeSanitize, markdownSanitizeSchema],
    rehypeHighlight,
    ...(dynamicPlugins.rehypeKatex ? [dynamicPlugins.rehypeKatex] : [])
  ];

  return (
    <ReactMarkdown
      remarkPlugins={remarkPlugins}
      rehypePlugins={rehypePlugins}
      urlTransform={markdownUrlTransform}
      components={{
        h1: ({ children }) => <h1 id={headingID(children)}>{children}</h1>,
        h2: ({ children }) => <h2 id={headingID(children)}>{children}</h2>,
        h3: ({ children }) => <h3 id={headingID(children)}>{children}</h3>,
        h4: ({ children }) => <h4 id={headingID(children)}>{children}</h4>,
        h5: ({ children }) => <h5 id={headingID(children)}>{children}</h5>,
        h6: ({ children }) => <h6 id={headingID(children)}>{children}</h6>,
        a({ href, children, ...props }) {
          function openDocumentLink(event: MouseEvent<HTMLAnchorElement>) {
            if (!href || !documentPath || !onDocumentLink || event.defaultPrevented || event.button !== 0) return;
            if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
            const target = resolveDocumentLink(href, documentPath);
            if (!target) return;
            event.preventDefault();
            onDocumentLink(target);
          }

          return (
            <a {...props} href={href} onClick={openDocumentLink}>
              {children}
            </a>
          );
        },
        pre({ children }) {
          return enableCodeCopy || isMermaidCodeNode(children) ? <>{children}</> : <pre>{children}</pre>;
        },
        code({ className, children, node }) {
          const rawCode = textFromNode(node as HastNode);
          const code = rawCode.replace(/\n$/, "");
          if (/language-mermaid/i.test(className ?? "") && containsMermaid(`\`\`\`mermaid\n${code}\n\`\`\``)) {
            return <MermaidBlock code={code} />;
          }
          if (enableCodeCopy && rawCode.endsWith("\n")) {
            return (
              <CopyableCodeBlock className={className} code={code}>
                {children}
              </CopyableCodeBlock>
            );
          }
          return <code className={className}>{children}</code>;
        }
      }}
    >
      {content}
    </ReactMarkdown>
  );
}
