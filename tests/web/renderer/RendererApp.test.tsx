import { act, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { RendererApp } from "../../../src/web/renderer/RendererApp";

afterEach(() => {
  delete window.webkit;
  delete window.__mdreviewRenderDocument;
  delete window.__mdreviewSetReaderLayout;
  delete window.__mdreviewPendingDocument;
  delete window.__mdreviewPendingReaderLayout;
});

describe("RendererApp", () => {
  it("renders a document queued before the React bridge effect runs", async () => {
    window.__mdreviewPendingDocument = {
      type: "renderDocument",
      path: "/tmp/early.md",
      name: "early.md",
      content: "# Early"
    };

    render(<RendererApp />);

    expect(await screen.findByRole("heading", { name: "Early" })).toBeInTheDocument();
  });

  it("renders markdown pushed by the native bridge", async () => {
    render(<RendererApp />);
    expect(screen.getByText("等待文档...")).toBeInTheDocument();

    act(() => {
      window.__mdreviewRenderDocument?.({
        type: "renderDocument",
        path: "/tmp/README.md",
        name: "README.md",
        content: "# Hello"
      });
    });

    expect(await screen.findByRole("heading", { name: "Hello" })).toBeInTheDocument();
  });

  it("scopes the WKWebView renderer with the native reader root class", async () => {
    window.__mdreviewPendingDocument = {
      type: "renderDocument",
      path: "/tmp/README.md",
      name: "README.md",
      content: "# Hello"
    };

    const { container } = render(<RendererApp />);

    expect(await screen.findByRole("heading", { name: "Hello" })).toBeInTheDocument();
    expect(container.querySelector(".native-reader")).toBeInTheDocument();
    expect(container.querySelector(".native-reader .markdown-body")).toBeInTheDocument();
  });

  it("enables one-click code copying in the native renderer", async () => {
    window.__mdreviewPendingDocument = {
      type: "renderDocument",
      path: "/tmp/code.md",
      name: "code.md",
      content: "```sh\nmdreview README.md\n```"
    };

    render(<RendererApp />);

    expect(await screen.findByRole("button", { name: "复制代码" })).toBeInTheDocument();
  });

  it("uses the outline reader layout when native navigation is visible", async () => {
    window.__mdreviewPendingDocument = {
      type: "renderDocument",
      path: "/tmp/outline.md",
      name: "outline.md",
      content: "# Outline",
      readerLayout: "withOutline"
    };

    const { container } = render(<RendererApp />);

    expect(await screen.findByRole("heading", { name: "Outline" })).toBeInTheDocument();
    expect(container.querySelector(".native-reader--with-outline")).toBeInTheDocument();

    act(() => {
      window.__mdreviewSetReaderLayout?.("centered");
    });

    expect(container.querySelector(".native-reader--with-outline")).not.toBeInTheDocument();
  });

  it("asks native code to open relative markdown links from the current document directory", async () => {
    const postMessage = vi.fn();
    window.webkit = { messageHandlers: { mdreview: { postMessage } } };
    window.__mdreviewPendingDocument = {
      type: "renderDocument",
      path: "/Users/me/docs/README.md",
      name: "README.md",
      content: "[Guide](guide.md#install)"
    };

    render(<RendererApp />);

    fireEvent.click(await screen.findByRole("link", { name: "Guide" }));

    expect(postMessage).toHaveBeenCalledWith({
      type: "openDocument",
      path: "/Users/me/docs/guide.md",
      hash: "install"
    });
  });
});
