import { render, screen, waitFor } from "@testing-library/react";
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
});
