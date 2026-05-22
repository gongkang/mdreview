import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const css = readFileSync("src/web/styles.css", "utf8");

describe("native reader stylesheet", () => {
  it("scopes long-form reader typography to the native renderer root", () => {
    expect(css).toContain(".native-reader .markdown-body");
    expect(css).toContain("max-width: 620px");
    expect(css).toContain("padding: 56px 40px 92px");
    expect(css).not.toMatch(/^\.markdown-body\s*{[^}]*max-width:\s*620px/ms);
  });
});
