import { describe, expect, it } from "vitest";
import { inlineRendererHtml } from "../../scripts/package-macos-app.mjs";

describe("inlineRendererHtml", () => {
  it("inlines the entry script and stylesheet for WKWebView file loading", async () => {
    const files = new Map([
      ["assets/index.js", 'import("./chunk.js"); const deps = ["./chunk.js"]; const literal = "$&";'],
      ["assets/index.css", "body{background:url(./font.woff2)}"]
    ]);
    const html = [
      '<script type="module" crossorigin src="./assets/index.js"></script>',
      '<link rel="stylesheet" crossorigin href="./assets/index.css">'
    ].join("\n");

    const result = await inlineRendererHtml(html, async (relativePath) => files.get(relativePath));

    expect(result).not.toContain('src="./assets/index.js"');
    expect(result).not.toContain('href="./assets/index.css"');
    expect(result).not.toContain("crossorigin");
    expect(result).toContain('import("./assets/chunk.js")');
    expect(result).toContain('["./assets/chunk.js"]');
    expect(result).toContain('const literal = "$&"');
    expect(result).toContain("url(./assets/font.woff2)");
  });
});
