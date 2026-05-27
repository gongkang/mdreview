import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { MarkdownView } from "../../src/web/components/MarkdownView";

describe("MarkdownView dynamic rendering", () => {
  it("keeps Mermaid source visible while dynamic renderer loads", () => {
    render(<MarkdownView content={"```mermaid\ngraph TD\nA-->B\n```"} onOutline={() => undefined} />);
    expect(screen.getByText(/graph TD/)).toBeInTheDocument();
  });

  it("does not nest Mermaid rendering placeholders inside code block pre elements", () => {
    const { container } = render(
      <MarkdownView content={"```mermaid\ngraph TD\nA-->B\n```"} onOutline={() => undefined} />
    );

    const pending = container.querySelector(".render-pending");

    expect(pending).toBeInTheDocument();
    expect(pending?.parentElement?.tagName).not.toBe("PRE");
  });

  it("renders math content without blanking the document", () => {
    render(<MarkdownView content={"# Math\n\nEuler: $e^{i\\pi}+1=0$"} onOutline={() => undefined} />);
    expect(screen.getByRole("heading", { name: "Math" })).toBeInTheDocument();
  });
});
