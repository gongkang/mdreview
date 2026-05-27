import { existsSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

describe("native app preview build", () => {
  it("uses the native renderer entrypoint only", () => {
    const entry = readFileSync("src/web/main.tsx", "utf8");

    expect(entry).toContain("./renderer/RendererApp");
    expect(entry).not.toContain("./App");
    expect(entry).not.toContain("location.protocol");
  });

  it("does not keep the legacy browser preview implementation", () => {
    const legacyPaths = [
      "src/web/App.tsx",
      "src/web/api-client.ts",
      "src/web/components/FileTree.tsx",
      "src/web/components/ErrorView.tsx",
      "src/web/components/Outline.tsx",
      "src/server/http-server.ts",
      "src/server/events.ts",
      "src/server/file-tree.ts",
      "src/server/path-utils.ts",
      "src/server/session.ts",
      "src/shared/errors.ts",
      "src/shared/security.ts",
      "src/shared/types.ts",
      "playwright.config.ts"
    ];

    expect(legacyPaths.filter((legacyPath) => existsSync(legacyPath))).toEqual([]);
  });

  it("does not ship browser preview scripts or dependencies", () => {
    const pkg = JSON.parse(readFileSync("package.json", "utf8")) as {
      scripts?: Record<string, string>;
      dependencies?: Record<string, string>;
      devDependencies?: Record<string, string>;
    };

    expect(pkg.scripts).not.toHaveProperty("test:e2e");
    expect(pkg.dependencies).not.toHaveProperty("chokidar");
    expect(pkg.dependencies).not.toHaveProperty("open");
    expect(pkg.devDependencies).not.toHaveProperty("@playwright/test");
  });
});
