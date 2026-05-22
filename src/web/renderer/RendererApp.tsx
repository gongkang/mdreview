import { useCallback, useEffect, useMemo, useState } from "react";
import { MarkdownView } from "../components/MarkdownView";
import type { OutlineItem } from "../components/Outline";
import { createNativeBridge } from "./bridge";
import { rewriteMarkdownResources } from "./resources";

export type RenderDocumentMessage = {
  type: "renderDocument";
  path: string;
  name: string;
  content: string;
  scrollPosition?: number;
};

export function RendererApp() {
  const bridge = useMemo(() => createNativeBridge(), []);
  const [document, setDocument] = useState<RenderDocumentMessage | null>(null);

  useEffect(() => {
    window.__mdreviewRenderDocument = setDocument;
    return () => {
      delete window.__mdreviewRenderDocument;
    };
  }, []);

  const onOutline = useCallback((items: OutlineItem[]) => {
    bridge.outlineChanged(items);
  }, [bridge]);

  if (!document) {
    return <main className="renderer-empty">等待文档...</main>;
  }

  return (
    <article className="markdown-body">
      <MarkdownView content={rewriteMarkdownResources(document.content)} onOutline={onOutline} />
    </article>
  );
}

declare global {
  interface Window {
    __mdreviewRenderDocument?: (message: RenderDocumentMessage) => void;
  }
}
