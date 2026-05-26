import type { OutlineItem } from "../components/Outline";

type HandlerMap = {
  mdreview?: {
    postMessage: (message: unknown) => void;
  };
};

export type NativeBridge = {
  outlineChanged: (items: OutlineItem[]) => void;
  openDocument: (path: string, hash?: string) => void;
  scrollChanged: (path: string, scrollPosition: number) => void;
  renderError: (path: string, message: string, blockId?: string) => void;
};

export function createNativeBridge(handlers: HandlerMap = window.webkit?.messageHandlers ?? {}): NativeBridge {
  function post(message: unknown) {
    handlers.mdreview?.postMessage(message);
  }
  return {
    outlineChanged: (items) => post({ type: "outlineChanged", items }),
    openDocument: (path, hash) => post({ type: "openDocument", path, ...(hash ? { hash } : {}) }),
    scrollChanged: (path, scrollPosition) => post({ type: "scrollChanged", path, scrollPosition }),
    renderError: (path, message, blockId) => post({ type: "renderError", path, message, blockId })
  };
}

declare global {
  interface Window {
    webkit?: {
      messageHandlers?: HandlerMap;
    };
  }
}
