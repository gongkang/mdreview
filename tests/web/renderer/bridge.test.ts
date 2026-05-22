import { describe, expect, it, vi } from "vitest";
import { createNativeBridge } from "../../../src/web/renderer/bridge";

describe("native bridge", () => {
  it("posts outlineChanged to the native message handler", () => {
    const postMessage = vi.fn();
    const bridge = createNativeBridge({ mdreview: { postMessage } });
    bridge.outlineChanged([{ id: "hello", text: "Hello", depth: 1 }]);
    expect(postMessage).toHaveBeenCalledWith({ type: "outlineChanged", items: [{ id: "hello", text: "Hello", depth: 1 }] });
  });
});
