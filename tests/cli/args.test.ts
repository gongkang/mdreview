import { describe, expect, it } from "vitest";
import { HELP_TEXT, parseArgs } from "../../src/cli/args";

describe("parseArgs", () => {
  it("parses file path and new-window", () => {
    expect(parseArgs(["docs", "--new-window"])).toEqual({
      action: "open",
      path: "docs",
      newWindow: true
    });
  });

  it("defaults to reusing an existing window", () => {
    expect(parseArgs(["README.md"])).toEqual({
      action: "open",
      path: "README.md",
      newWindow: false
    });
  });

  it("returns help and version actions without requiring a path", () => {
    expect(parseArgs(["--help"])).toEqual({ action: "help" });
    expect(parseArgs(["--version"])).toEqual({ action: "version" });
  });

  it("rejects removed browser-server flags", () => {
    expect(() => parseArgs(["docs", "--port", "4010"])).toThrow("不再支持参数：--port");
    expect(() => parseArgs(["docs", "--no-open"])).toThrow("不再支持参数：--no-open");
  });

  it("prints Chinese help text", () => {
    expect(HELP_TEXT).toContain("用法：mdreview <文件或目录>");
  });
});
