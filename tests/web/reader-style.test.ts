import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const css = readFileSync("src/web/styles.css", "utf8");

describe("native reader stylesheet", () => {
  it("scopes long-form reader typography to the native renderer root", () => {
    expect(css).toContain(".native-reader .markdown-body");
    expect(css).toContain("max-width: 980px");
    expect(css).toContain("padding: 56px clamp(32px, 6vw, 72px) 92px");
    expect(css).not.toMatch(/^\.markdown-body\s*{[^}]*max-width:\s*620px/ms);
  });

  it("left-aligns native reader content when the outline is visible", () => {
    expect(css).toContain(".native-reader.native-reader--with-outline .markdown-body");
    expect(css).toContain("margin-left: 0");
    expect(css).toContain("margin-right: auto");
    expect(css).toContain("max-width: 1080px");
  });

  it("uses comfortable native reader type sizes", () => {
    expect(css).toMatch(/\.native-reader \.markdown-body\s*{[^}]*font-size:\s*16px/ms);
    expect(css).toMatch(/\.native-reader \.markdown-body h1\s*{[^}]*font-size:\s*38px/ms);
    expect(css).toMatch(/\.native-reader \.markdown-body h2\s*{[^}]*font-size:\s*27px/ms);
    expect(css).toMatch(/\.native-reader \.markdown-body h3\s*{[^}]*font-size:\s*21px/ms);
    expect(css).toMatch(/\.native-reader \.markdown-body pre code\s*{[^}]*font-size:\s*13px/ms);
  });

  it("styles Markdown tables with visible cells", () => {
    expect(css).toContain(".native-reader .markdown-body th");
    expect(css).toContain(".native-reader .markdown-body td");
    expect(css).toContain("border: 1px solid #d8dee4");
    expect(css).toContain("background: #f6f8fa");
  });
});
