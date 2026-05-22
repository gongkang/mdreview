import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { readFile, realpath, stat } from "node:fs/promises";
import path from "node:path";
import { apiError } from "../shared/errors";
import { API_TOKEN_HEADER } from "../shared/security";
import type { PreviewSession } from "./session";
import { findRootReadme, listMarkdownFiles } from "./file-tree";
import { assertInsideRoot } from "./path-utils";

export type StartPreviewServerOptions = {
  session: PreviewSession;
  port?: number;
  staticDir?: string;
};

export type StartedPreviewServer = {
  url: string;
  port: number;
  close: () => Promise<void>;
};

function sendJson(response: ServerResponse, status: number, body: unknown) {
  response.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store"
  });
  response.end(JSON.stringify(body));
}

function requireToken(request: IncomingMessage, response: ServerResponse, token: string): boolean {
  if (request.headers[API_TOKEN_HEADER] !== token) {
    sendJson(response, 401, apiError("UNAUTHORIZED", "Invalid preview session token"));
    return false;
  }
  return true;
}

function contentTypeFor(assetPath: string): string {
  const ext = path.extname(assetPath).toLowerCase();
  if (ext === ".js") return "text/javascript; charset=utf-8";
  if (ext === ".css") return "text/css; charset=utf-8";
  if (ext === ".json") return "application/json; charset=utf-8";
  if (ext === ".svg") return "image/svg+xml";
  if (ext === ".woff2") return "font/woff2";
  return "text/html; charset=utf-8";
}

async function readDocument(session: PreviewSession, relativePath: string) {
  const realPath = session.mode === "file" ? session.rootRealPath : await assertInsideRoot(session.rootRealPath, relativePath);
  const stats = await stat(realPath);
  const content = await readFile(realPath, "utf8");
  return {
    path: session.mode === "file" ? path.basename(session.rootPath) : relativePath,
    name: path.basename(realPath),
    mtime: stats.mtimeMs,
    content
  };
}

export async function startPreviewServer(options: StartPreviewServerOptions): Promise<StartedPreviewServer> {
  const { session, staticDir = path.resolve("dist/client") } = options;
  const staticRoot = path.resolve(staticDir);

  async function sendStatic(response: ServerResponse, assetPath: string) {
    const realStaticRoot = await realpath(staticRoot);
    const realFile = await realpath(path.resolve(staticRoot, assetPath));
    const relative = path.relative(realStaticRoot, realFile);
    if (relative.startsWith("..") || path.isAbsolute(relative)) {
      response.writeHead(403, { "content-type": "text/plain; charset=utf-8" });
      response.end("Forbidden");
      return;
    }
    const body = await readFile(realFile);
    response.writeHead(200, { "content-type": contentTypeFor(assetPath) });
    response.end(body);
  }

  const server = createServer(async (request, response) => {
    const url = new URL(request.url ?? "/", "http://127.0.0.1");

    if (url.pathname.startsWith("/api/")) {
      if (!requireToken(request, response, session.token)) return;
      try {
        if (url.pathname === "/api/session") {
          sendJson(response, 200, {
            mode: session.mode,
            rootName: session.rootName,
            defaultDocument: session.mode === "directory" ? await findRootReadme(session.rootRealPath) : path.basename(session.rootPath)
          });
          return;
        }
        if (url.pathname === "/api/files") {
          sendJson(response, 200, await listMarkdownFiles(session.rootRealPath));
          return;
        }
        if (url.pathname === "/api/document") {
          sendJson(response, 200, await readDocument(session, url.searchParams.get("path") ?? ""));
          return;
        }
        sendJson(response, 404, apiError("NOT_FOUND", "API route not found"));
      } catch {
        sendJson(response, 404, apiError("FILE_NOT_FOUND", "File not found"));
      }
      return;
    }

    const assetPath = url.pathname === "/" ? "index.html" : url.pathname.slice(1);
    try {
      await sendStatic(response, decodeURIComponent(assetPath));
    } catch {
      await sendStatic(response, "index.html");
    }
  });

  await new Promise<void>((resolve, reject) => {
    server.once("error", reject);
    server.listen(options.port ?? 0, "127.0.0.1", () => resolve());
  });

  const address = server.address();
  if (!address || typeof address === "string") throw new Error("Server did not bind to a TCP port");
  return {
    port: address.port,
    url: `http://127.0.0.1:${address.port}`,
    close: () => new Promise((resolve, reject) => server.close((error) => (error ? reject(error) : resolve())))
  };
}
