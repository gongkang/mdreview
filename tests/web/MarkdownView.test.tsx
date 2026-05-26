import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { MarkdownView, outlineFromMarkdown } from "../../src/web/components/MarkdownView";
import { toMdreviewResourceUrl } from "../../src/web/renderer/resources";

afterEach(() => {
  vi.restoreAllMocks();
});

describe("MarkdownView", () => {
  it("renders headings with stable anchors and GFM task lists", () => {
    render(<MarkdownView content={"# Hello World\n\n- [x] shipped"} onOutline={() => undefined} />);
    expect(screen.getByRole("heading", { name: "Hello World" })).toHaveAttribute("id", "hello-world");
    expect(screen.getByRole("checkbox")).toBeChecked();
  });

  it("renders Obsidian-style GFM tables as table elements", () => {
    render(
      <MarkdownView
        content={["| 项目 | 状态 |", "| :--- | ---: |", "| 图片 | 已支持 |"].join("\n")}
        onOutline={() => undefined}
      />
    );

    expect(screen.getByRole("table")).toBeInTheDocument();
    expect(screen.getByRole("columnheader", { name: "项目" })).toBeInTheDocument();
    expect(screen.getByRole("cell", { name: "已支持" })).toBeInTheDocument();
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

  it("excludes headings inside fenced code blocks from the outline", () => {
    const outline = outlineFromMarkdown(
      [
        "# Visible",
        "",
        "~~~markdown",
        "# Hidden",
        "## Usage",
        "```bash",
        "mdreview README.md",
        "```",
        "~~~",
        "",
        "## Also Visible"
      ].join("\n")
    );

    expect(outline.map((item) => item.text)).toEqual(["Visible", "Also Visible"]);
  });

  it("does not execute script or event handler HTML", () => {
    const alertSpy = vi.spyOn(window, "alert").mockImplementation(() => undefined);
    render(<MarkdownView content={'<img src=x onerror="alert(1)"><script>alert(2)</script>'} onOutline={() => undefined} />);
    expect(alertSpy).not.toHaveBeenCalled();
    expect(document.querySelector("script")).toBeNull();
    expect(document.querySelector("[onerror]")).toBeNull();
  });

  it("rewrites markdown image paths through the native resource resolver", () => {
    render(
      <MarkdownView
        content={'![Logo](./images/logo.png "Project logo")'}
        resourceUrlResolver={toMdreviewResourceUrl}
        onOutline={() => undefined}
      />
    );

    const image = screen.getByRole("img", { name: "Logo" });
    expect(image).toHaveAttribute("src", "mdreview-resource://./images/logo.png");
    expect(image).toHaveAttribute("title", "Project logo");
  });

  it("rewrites HTML image paths through the native resource resolver", () => {
    render(
      <MarkdownView
        content={'<img alt="Diagram" src="file:///Users/me/docs/diagram%20wide.svg">'}
        resourceUrlResolver={toMdreviewResourceUrl}
        onOutline={() => undefined}
      />
    );

    expect(screen.getByRole("img", { name: "Diagram" })).toHaveAttribute(
      "src",
      "mdreview-resource:///Users/me/docs/diagram%20wide.svg"
    );
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
