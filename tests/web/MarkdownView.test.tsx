import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { MarkdownView } from "../../src/web/components/MarkdownView";

describe("MarkdownView", () => {
  it("renders headings with stable anchors and GFM task lists", () => {
    render(<MarkdownView content={"# Hello World\n\n- [x] shipped"} onOutline={() => undefined} />);
    expect(screen.getByRole("heading", { name: "Hello World" })).toHaveAttribute("id", "hello-world");
    expect(screen.getByRole("checkbox")).toBeChecked();
  });

  it("does not execute script or event handler HTML", () => {
    const alertSpy = vi.spyOn(window, "alert").mockImplementation(() => undefined);
    render(<MarkdownView content={'<img src=x onerror="alert(1)"><script>alert(2)</script>'} onOutline={() => undefined} />);
    expect(alertSpy).not.toHaveBeenCalled();
    expect(document.querySelector("script")).toBeNull();
    expect(document.querySelector("[onerror]")).toBeNull();
  });
});
