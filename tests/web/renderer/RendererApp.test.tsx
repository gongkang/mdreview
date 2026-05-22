import { act, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { RendererApp } from "../../../src/web/renderer/RendererApp";

afterEach(() => {
  delete window.__mdreviewRenderDocument;
  delete window.__mdreviewPendingDocument;
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
});
