import { useEffect, useMemo } from "react";
import ReactMarkdown from "react-markdown";
import rehypeHighlight from "rehype-highlight";
import rehypeRaw from "rehype-raw";
import rehypeSanitize from "rehype-sanitize";
import remarkGfm from "remark-gfm";
import type { OutlineItem } from "./Outline";
import { markdownSanitizeSchema } from "../markdown/sanitize";
import "highlight.js/styles/github.css";

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

export function MarkdownView({ content, onOutline }: { content: string; onOutline: (items: OutlineItem[]) => void }) {
  const outline = useMemo(() => outlineFromMarkdown(content), [content]);
  useEffect(() => {
    onOutline(outline);
  }, [onOutline, outline]);

  return (
    <ReactMarkdown
      remarkPlugins={[remarkGfm]}
      rehypePlugins={[rehypeRaw, [rehypeSanitize, markdownSanitizeSchema], rehypeHighlight]}
      components={{
        h1: ({ children }) => <h1 id={slugify(String(children))}>{children}</h1>,
        h2: ({ children }) => <h2 id={slugify(String(children))}>{children}</h2>,
        h3: ({ children }) => <h3 id={slugify(String(children))}>{children}</h3>
      }}
    >
      {content}
    </ReactMarkdown>
  );
}
