import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";

describe("vite config", () => {
  it("uses relative asset URLs so the renderer works from file:// inside the app bundle", () => {
    const config = readFileSync("vite.config.ts", "utf8");

    expect(config).toContain('base: "./"');
  });

  it("inlines dynamic imports so Mermaid can render from file:// inside the app bundle", () => {
    const config = readFileSync("vite.config.ts", "utf8");

    expect(config).toContain("inlineDynamicImports: true");
  });
});
