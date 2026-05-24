import { useEffect, useMemo, useState } from "react";
import type { ReactNode } from "react";
import ReactMarkdown from "react-markdown";
import rehypeHighlight from "rehype-highlight";
import rehypeRaw from "rehype-raw";
import rehypeSanitize from "rehype-sanitize";
import remarkGfm from "remark-gfm";
import type { PluggableList } from "unified";
import type { OutlineItem } from "./Outline";
import { containsMath, containsMermaid } from "../markdown/detect";
import { markdownSanitizeSchema } from "../markdown/sanitize";
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
};

type HastNode = {
  value?: unknown;
  children?: HastNode[];
};

function slugify(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}

export function outlineFromMarkdown(content: string): OutlineItem[] {
  return content
    .split("\n")
    .map((line) => /^(#{1,6})\s+(.+)$/.exec(line))
    .filter((match): match is RegExpExecArray => Boolean(match))
    .map((match) => ({ depth: match[1].length, text: match[2], id: slugify(match[2]) }));
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

export function MarkdownView({ content, onOutline, enableCodeCopy = false }: MarkdownViewProps) {
  const outline = useMemo(() => outlineFromMarkdown(content), [content]);
  const [dynamicPlugins, setDynamicPlugins] = useState<DynamicPlugins>({});

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
  const rehypePlugins: PluggableList = dynamicPlugins.rehypeKatex
    ? [rehypeRaw, [rehypeSanitize, markdownSanitizeSchema], rehypeHighlight, dynamicPlugins.rehypeKatex]
    : [rehypeRaw, [rehypeSanitize, markdownSanitizeSchema], rehypeHighlight];

  return (
    <ReactMarkdown
      remarkPlugins={remarkPlugins}
      rehypePlugins={rehypePlugins}
      components={{
        h1: ({ children }) => <h1 id={slugify(String(children))}>{children}</h1>,
        h2: ({ children }) => <h2 id={slugify(String(children))}>{children}</h2>,
        h3: ({ children }) => <h3 id={slugify(String(children))}>{children}</h3>,
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
