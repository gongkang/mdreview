import { describe, expect, it } from "vitest";
import { rewriteMarkdownResources } from "../../../src/web/renderer/resources";

describe("rewriteMarkdownResources", () => {
  it("rewrites relative markdown images to mdreview-resource URLs", () => {
    expect(rewriteMarkdownResources("![Logo](./logo.png)")).toBe("![Logo](mdreview-resource://./logo.png)");
  });

  it("keeps remote URLs unchanged", () => {
    expect(rewriteMarkdownResources("![Logo](https://example.com/logo.png)")).toBe("![Logo](https://example.com/logo.png)");
  });
});
