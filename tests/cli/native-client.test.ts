import net from "node:net";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { sendOpenRequest } from "../../src/cli/native-client";

let cleanupPath: string | undefined;

afterEach(async () => {
  if (cleanupPath) await rm(cleanupPath, { force: true });
  cleanupPath = undefined;
});

describe("native app socket client", () => {
  it("sends an open request and reads an ack", async () => {
    const dir = await mkdtemp(path.join(tmpdir(), "mdreview-ipc-"));
    const socketPath = path.join(dir, "mdreview.sock");
    cleanupPath = socketPath;

    const server = net.createServer((socket) => {
      socket.on("data", (chunk) => {
        const message = JSON.parse(chunk.toString("utf8"));
        expect(message).toMatchObject({ kind: "openFile", path: "/tmp/README.md", newWindow: false });
        socket.end(JSON.stringify({ accepted: true, action: "opened", message: "已打开" }) + "\n");
      });
    });

    await new Promise<void>((resolve) => server.listen(socketPath, resolve));
    const response = await sendOpenRequest(socketPath, { kind: "openFile", path: "/tmp/README.md", newWindow: false }, 1000);
    server.close();

    expect(response).toEqual({ accepted: true, action: "opened", message: "已打开" });
  });
});
