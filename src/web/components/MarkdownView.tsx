import { useEffect, useMemo, useState } from "react";
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

export function MarkdownView({ content, onOutline }: { content: string; onOutline: (items: OutlineItem[]) => void }) {
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
        code({ className, children }) {
          const code = String(children).replace(/\n$/, "");
          if (/language-mermaid/i.test(className ?? "") && containsMermaid(`\`\`\`mermaid\n${code}\n\`\`\``)) {
            return <MermaidBlock code={code} />;
          }
          return <code className={className}>{children}</code>;
        }
      }}
    >
      {content}
    </ReactMarkdown>
  );
}
