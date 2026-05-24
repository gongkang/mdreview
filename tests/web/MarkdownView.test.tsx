import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { MarkdownView, outlineFromMarkdown } from "../../src/web/components/MarkdownView";

afterEach(() => {
  vi.restoreAllMocks();
});

describe("MarkdownView", () => {
  it("renders headings with stable anchors and GFM task lists", () => {
    render(<MarkdownView content={"# Hello World\n\n- [x] shipped"} onOutline={() => undefined} />);
    expect(screen.getByRole("heading", { name: "Hello World" })).toHaveAttribute("id", "hello-world");
    expect(screen.getByRole("checkbox")).toBeChecked();
  });

  it("keeps non-Latin heading anchors non-empty and unique", () => {
    const content = "# mdreview\n\n## 使用\n\n## 开发\n\n## 使用\n";
    const outline = outlineFromMarkdown(content);

    expect(outline.map((item) => item.id)).toEqual(["mdreview", "使用", "开发", "使用-1"]);

    render(<MarkdownView content={content} onOutline={() => undefined} />);

    expect(screen.getAllByRole("heading", { name: "使用" })[0]).toHaveAttribute("id", "使用");
    expect(screen.getByRole("heading", { name: "开发" })).toHaveAttribute("id", "开发");
    expect(screen.getAllByRole("heading", { name: "使用" })[1]).toHaveAttribute("id", "使用-1");
  });

  it("does not execute script or event handler HTML", () => {
    const alertSpy = vi.spyOn(window, "alert").mockImplementation(() => undefined);
    render(<MarkdownView content={'<img src=x onerror="alert(1)"><script>alert(2)</script>'} onOutline={() => undefined} />);
    expect(alertSpy).not.toHaveBeenCalled();
    expect(document.querySelector("script")).toBeNull();
    expect(document.querySelector("[onerror]")).toBeNull();
  });

  it("copies fenced code blocks when native copy controls are enabled", async () => {
    const writeText = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(window.navigator, "clipboard", {
      configurable: true,
      value: { writeText }
    });

    render(<MarkdownView content={"```ts\nconst answer = 42;\n```"} enableCodeCopy onOutline={() => undefined} />);

    fireEvent.click(screen.getByRole("button", { name: "复制代码" }));

    await waitFor(() => expect(writeText).toHaveBeenCalledWith("const answer = 42;"));
    expect(await screen.findByRole("button", { name: "已复制代码" })).toBeInTheDocument();
  });
});
