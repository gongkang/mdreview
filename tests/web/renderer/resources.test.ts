import { describe, expect, it } from "vitest";
import { toMdreviewResourceUrl } from "../../../src/web/renderer/resources";

describe("toMdreviewResourceUrl", () => {
  it("rewrites relative image paths to mdreview-resource URLs", () => {
    expect(toMdreviewResourceUrl("./logo.png")).toBe("mdreview-resource://./logo.png");
  });

  it("rewrites absolute filesystem image paths to mdreview-resource URLs", () => {
    expect(toMdreviewResourceUrl("/Users/me/images/logo.png")).toBe("mdreview-resource:///Users/me/images/logo.png");
  });

  it("rewrites file URLs to mdreview-resource filesystem paths", () => {
    expect(toMdreviewResourceUrl("file:///Users/me/images/logo%20wide.png")).toBe(
      "mdreview-resource:///Users/me/images/logo%20wide.png"
    );
  });

  it("keeps remote and existing resource URLs unchanged", () => {
    expect(toMdreviewResourceUrl("https://example.com/logo.png")).toBe("https://example.com/logo.png");
    expect(toMdreviewResourceUrl("mdreview-resource://./logo.png")).toBe("mdreview-resource://./logo.png");
  });
});
