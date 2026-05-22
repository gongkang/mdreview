import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { ErrorView } from "../../src/web/components/ErrorView";

describe("ErrorView", () => {
  it("renders actionable session errors", () => {
    render(<ErrorView title="Preview session unavailable" detail="Invalid preview session token. Re-run mdreview." />);
    expect(screen.getByRole("alert")).toHaveTextContent("Re-run mdreview");
  });
});
