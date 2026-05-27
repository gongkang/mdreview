import { useCallback, useEffect, useMemo, useState } from "react";
import { MarkdownView, type DocumentLinkTarget } from "../components/MarkdownView";
import type { OutlineItem } from "../markdown/outline";
import { createNativeBridge } from "./bridge";
import { toMdreviewResourceUrl } from "./resources";

export type RenderDocumentMessage = {
  type: "renderDocument";
  path: string;
  name: string;
  content: string;
  scrollPosition?: number;
  readerLayout?: ReaderLayout;
};

type ReaderLayout = "centered" | "withOutline";

export function RendererApp() {
  const bridge = useMemo(() => createNativeBridge(), []);
  const [document, setDocument] = useState<RenderDocumentMessage | null>(window.__mdreviewPendingDocument ?? null);
  const [readerLayout, setReaderLayout] = useState<ReaderLayout>(
    window.__mdreviewPendingReaderLayout ?? window.__mdreviewPendingDocument?.readerLayout ?? "centered"
  );

  useEffect(() => {
    window.__mdreviewRenderDocument = (message) => {
      window.__mdreviewPendingDocument = message;
      setDocument(message);
      setReaderLayout(message.readerLayout ?? "centered");
    };
    window.__mdreviewSetReaderLayout = (layout) => {
      window.__mdreviewPendingReaderLayout = layout;
      setReaderLayout(layout);
    };
    if (window.__mdreviewPendingDocument) {
      setDocument(window.__mdreviewPendingDocument);
      setReaderLayout(window.__mdreviewPendingDocument.readerLayout ?? window.__mdreviewPendingReaderLayout ?? "centered");
    }
    return () => {
      delete window.__mdreviewRenderDocument;
      delete window.__mdreviewSetReaderLayout;
    };
  }, []);

  const onOutline = useCallback((items: OutlineItem[]) => {
    bridge.outlineChanged(items);
  }, [bridge]);

  const onDocumentLink = useCallback((target: DocumentLinkTarget) => {
    bridge.openDocument(target.path, target.hash);
  }, [bridge]);

  if (!document) {
    return <main className="native-reader renderer-empty">等待文档...</main>;
  }

  return (
    <main className={`native-reader ${readerLayout === "withOutline" ? "native-reader--with-outline" : ""}`}>
      <article className="markdown-body">
        <MarkdownView
          content={document.content}
          documentPath={document.path}
          enableCodeCopy
          onDocumentLink={onDocumentLink}
          resourceUrlResolver={toMdreviewResourceUrl}
          onOutline={onOutline}
        />
      </article>
    </main>
  );
}

declare global {
  interface Window {
    __mdreviewRenderDocument?: (message: RenderDocumentMessage) => void;
    __mdreviewSetReaderLayout?: (layout: ReaderLayout) => void;
    __mdreviewPendingDocument?: RenderDocumentMessage;
    __mdreviewPendingReaderLayout?: ReaderLayout;
  }
}
