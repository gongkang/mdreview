import { describe, expect, it } from "vitest";
import { parseArgs } from "../../src/cli/args";

describe("parseArgs", () => {
  it("parses path, port, and no-open", () => {
    expect(parseArgs(["README.md", "--port", "4010", "--no-open"])).toEqual({
      action: "serve",
      path: "README.md",
      port: 4010,
      openBrowser: false
    });
  });

  it("defaults to opening the browser", () => {
    expect(parseArgs(["docs"])).toEqual({
      action: "serve",
      path: "docs",
      port: undefined,
      openBrowser: true
    });
  });

  it("returns help and version actions without requiring a path", () => {
    expect(parseArgs(["--help"])).toEqual({ action: "help" });
    expect(parseArgs(["--version"])).toEqual({ action: "version" });
  });

  it("rejects missing path", () => {
    expect(() => parseArgs([])).toThrow("Usage: mdreview <file-or-directory>");
  });
});
