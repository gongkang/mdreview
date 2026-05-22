import { mkdir, mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { createPreviewSession } from "../../src/server/session";
import { startPreviewServer, type StartedPreviewServer } from "../../src/server/http-server";
import { API_TOKEN_HEADER } from "../../src/shared/security";

let server: StartedPreviewServer | undefined;

afterEach(async () => {
  await server?.close();
  server = undefined;
});

async function fixture() {
  const root = await mkdtemp(path.join(tmpdir(), "mdreview-api-"));
  await writeFile(path.join(root, "README.md"), "# Hello");
  return root;
}

async function staticFixture() {
  const parent = await mkdtemp(path.join(tmpdir(), "mdreview-static-"));
  const staticDir = path.join(parent, "client");
  await mkdir(staticDir);
  await writeFile(path.join(staticDir, "index.html"), "<main>mdreview</main>");
  await writeFile(path.join(staticDir, "app.css"), "body { color: black; }");
  await writeFile(path.join(parent, "secret.css"), "secret");
  return staticDir;
}

describe("preview server APIs", () => {
  it("rejects API calls without the session token", async () => {
    const session = await createPreviewSession(await fixture());
    server = await startPreviewServer({ session });
    const response = await fetch(`${server.url}/api/session`);
    expect(response.status).toBe(401);
  });

  it("returns session, files, and document content with a valid token", async () => {
    const session = await createPreviewSession(await fixture());
    server = await startPreviewServer({ session });
    const headers = { [API_TOKEN_HEADER]: session.token };

    const sessionResponse = await fetch(`${server.url}/api/session`, { headers });
    expect(await sessionResponse.json()).toMatchObject({
      mode: "directory",
      rootName: path.basename(session.rootPath),
      defaultDocument: "README.md"
    });

    const filesResponse = await fetch(`${server.url}/api/files`, { headers });
    expect(JSON.stringify(await filesResponse.json())).toContain("README.md");

    const documentResponse = await fetch(`${server.url}/api/document?path=README.md`, { headers });
    expect(await documentResponse.json()).toMatchObject({
      path: "README.md",
      name: "README.md",
      content: "# Hello"
    });
  });

  it("serves static assets with MIME types and blocks static path traversal", async () => {
    const session = await createPreviewSession(await fixture());
    server = await startPreviewServer({ session, staticDir: await staticFixture() });

    const cssResponse = await fetch(`${server.url}/app.css`);
    expect(cssResponse.headers.get("content-type")).toContain("text/css");

    const escapedResponse = await fetch(`${server.url}/%2e%2e%2fsecret.css`);
    expect(escapedResponse.status).toBe(403);
  });
});
