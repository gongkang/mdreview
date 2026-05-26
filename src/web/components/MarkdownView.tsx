import { isValidElement, useEffect, useMemo, useState } from "react";
import type { ReactNode } from "react";
import ReactMarkdown, { defaultUrlTransform } from "react-markdown";
import rehypeHighlight from "rehype-highlight";
import rehypeRaw from "rehype-raw";
import rehypeSanitize from "rehype-sanitize";
import remarkGfm from "remark-gfm";
import type { PluggableList } from "unified";
import type { OutlineItem } from "./Outline";
import { containsMath, containsMermaid } from "../markdown/detect";
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
  resourceUrlResolver?: ResourceUrlResolver;
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

export function MarkdownView({ content, onOutline, enableCodeCopy = false, resourceUrlResolver }: MarkdownViewProps) {
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
        pre({ children }) {
          return enableCodeCopy ? <>{children}</> : <pre>{children}</pre>;
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
