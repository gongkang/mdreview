import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { startPreviewServer, type StartedPreviewServer } from "../../src/server/http-server";
import { createPreviewSession } from "../../src/server/session";
import { API_TOKEN_HEADER } from "../../src/shared/security";

let server: StartedPreviewServer | undefined;

afterEach(async () => {
  await server?.close();
  server = undefined;
});

describe("server security", () => {
  it("blocks traversal outside the preview root", async () => {
    const root = await mkdtemp(path.join(tmpdir(), "mdreview-sec-"));
    await writeFile(path.join(root, "README.md"), "# Safe");
    const session = await createPreviewSession(root);
    server = await startPreviewServer({ session });
    const response = await fetch(`${server.url}/api/document?path=../secret.md`, {
      headers: { [API_TOKEN_HEADER]: session.token }
    });
    expect(response.status).toBe(404);
  });
});
