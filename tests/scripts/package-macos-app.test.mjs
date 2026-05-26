import { describe, expect, it } from "vitest";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { copyBundleIcon, inlineRendererHtml } from "../../scripts/package-macos-app.mjs";

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

describe("copyBundleIcon", () => {
  it("copies the app icon into the bundle resources directory", async () => {
    const tempDir = await mkdtemp(path.join(tmpdir(), "mdreview-icon-"));
    try {
      const nativeDir = path.join(tempDir, "native");
      const resourcesDir = path.join(tempDir, "Contents", "Resources");
      await mkdir(nativeDir);
      await mkdir(resourcesDir, { recursive: true });
      await writeFile(path.join(nativeDir, "AppIcon.icns"), "icon data");

      await copyBundleIcon({ nativeDir, resourcesDir });

      await expect(readFile(path.join(resourcesDir, "AppIcon.icns"), "utf8")).resolves.toBe("icon data");
    } finally {
      await rm(tempDir, { recursive: true, force: true });
    }
  });

  it("declares the bundled icon in Info.plist", async () => {
    const plist = await readFile(path.resolve("native", "Info.plist"), "utf8");

    expect(plist).toMatch(/<key>CFBundleIconFile<\/key>\s*<string>AppIcon<\/string>/);
  });

  it("keeps the icon artwork inside a Dock-safe margin", async () => {
    const svg = await readFile(path.resolve("native", "AppIcon.svg"), "utf8");
    const baseRect = svg.match(/<rect\b[^>]*id="icon-base"[^>]*>/)?.[0] ?? "";
    const readNumber = (name) => Number(baseRect.match(new RegExp(`${name}="([0-9.]+)"`))?.[1]);

    expect(baseRect).not.toBe("");
    expect(readNumber("x")).toBeGreaterThanOrEqual(96);
    expect(readNumber("y")).toBeGreaterThanOrEqual(96);
    expect(readNumber("width")).toBeLessThanOrEqual(832);
    expect(readNumber("height")).toBeLessThanOrEqual(832);
  });
});
