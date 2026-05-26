import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { App } from "../../src/web/App";

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("App layout", () => {
  it("shows file tree in directory mode", async () => {
    window.history.pushState(null, "", "/#token=test-token");
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string) => {
        if (url.endsWith("/api/session")) {
          return Response.json({ mode: "directory", rootName: "docs", defaultDocument: "README.md" });
        }
        if (url.endsWith("/api/files")) {
          return Response.json([{ type: "file", name: "README.md", path: "README.md" }]);
        }
        return Response.json({ path: "README.md", name: "README.md", mtime: 1, content: "# Hello" });
      })
    );

    render(<App />);
    await waitFor(() => expect(screen.getByText("README.md")).toBeInTheDocument());
    expect(screen.getByLabelText("Markdown files")).toBeInTheDocument();
  });

  it("hides file tree in single-file mode", async () => {
    window.history.pushState(null, "", "/#token=test-token");
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string) => {
        if (url.endsWith("/api/session")) {
          return Response.json({ mode: "file", rootName: "README.md", defaultDocument: "README.md" });
        }
        return Response.json({ path: "README.md", name: "README.md", mtime: 1, content: "# Hello" });
      })
    );

    render(<App />);
    await waitFor(() => expect(screen.getByText("README.md")).toBeInTheDocument());
    expect(screen.queryByLabelText("Markdown files")).not.toBeInTheDocument();
  });

  it("does not apply the native reader root class to browser preview", async () => {
    window.history.pushState(null, "", "/#token=test-token");
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string) => {
        if (url.endsWith("/api/session")) {
          return Response.json({ mode: "file", rootName: "README.md", defaultDocument: "README.md" });
        }
        return Response.json({ path: "README.md", name: "README.md", mtime: 1, content: "# Hello" });
      })
    );

    const { container } = render(<App />);
    await waitFor(() => expect(screen.getByText("README.md")).toBeInTheDocument());
    expect(container.querySelector(".native-reader")).toBeNull();
  });

  it("opens relative markdown links in directory mode without leaving the preview", async () => {
    window.history.pushState(null, "", "/#token=test-token");
    const fetch = vi.fn(async (url: string) => {
      if (url.endsWith("/api/session")) {
        return Response.json({ mode: "directory", rootName: "docs", defaultDocument: "README.md" });
      }
      if (url.endsWith("/api/files")) {
        return Response.json([
          { type: "file", name: "README.md", path: "README.md" },
          { type: "file", name: "guide.md", path: "guide.md" }
        ]);
      }
      if (url.endsWith("/api/document?path=guide.md")) {
        return Response.json({ path: "guide.md", name: "guide.md", mtime: 2, content: "# Guide" });
      }
      return Response.json({
        path: "README.md",
        name: "README.md",
        mtime: 1,
        content: "[Guide](guide.md)"
      });
    });
    vi.stubGlobal("fetch", fetch);

    render(<App />);

    const link = await screen.findByRole("link", { name: "Guide" });
    fireEvent.click(link);

    expect(await screen.findByRole("heading", { name: "Guide" })).toBeInTheDocument();
    expect(fetch).toHaveBeenCalledWith("/api/document?path=guide.md", {
      headers: { "x-mdreview-token": "test-token" }
    });
  });
});
