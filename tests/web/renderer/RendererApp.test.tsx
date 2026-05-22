import { act, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { RendererApp } from "../../../src/web/renderer/RendererApp";

afterEach(() => {
  delete window.__mdreviewRenderDocument;
});

describe("RendererApp", () => {
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
});
