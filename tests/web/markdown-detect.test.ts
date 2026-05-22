import { describe, expect, it } from "vitest";
import { containsMath, containsMermaid } from "../../src/web/markdown/detect";

describe("markdown dynamic feature detection", () => {
  it("detects Mermaid fenced code blocks", () => {
    expect(containsMermaid("```mermaid\ngraph TD\nA-->B\n```")).toBe(true);
    expect(containsMermaid("```ts\nconst value = 1\n```")).toBe(false);
  });

  it("detects inline and block math", () => {
    expect(containsMath("Euler: $e^{i\\pi}+1=0$")).toBe(true);
    expect(containsMath("$$\\int_0^1 x dx$$")).toBe(true);
    expect(containsMath("plain text")).toBe(false);
  });
});
