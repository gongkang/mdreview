# mdreview MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS-first `mdreview <file-or-directory>` CLI that starts a local browser-based Markdown previewer with secure local file APIs, directory browsing, outline navigation, single-file auto refresh, GFM, code highlighting, Mermaid, and math rendering.

**Architecture:** A Node.js/TypeScript CLI starts a local `127.0.0.1` HTTP server, generates a per-session token, serves the Vite-built browser app, and exposes token-protected file APIs. The browser app renders Markdown with React, sanitizes HTML, dynamically loads Mermaid and math support, and switches between directory and single-file layouts based on `/api/session`.

**Tech Stack:** Node.js 20+, TypeScript, Vite, React, Vitest, Playwright, `react-markdown`, `remark-gfm`, `remark-math`, `rehype-raw`, `rehype-sanitize`, `rehype-highlight`, `rehype-katex`, `mermaid`, `katex`, `chokidar`, `open`, `tsup`.

---

## Scope Check

This plan implements one cohesive MVP. It intentionally does not implement project config files, full-text search, export, themes, or desktop app mode.

## File Structure

- `package.json`: package metadata, CLI bin, scripts, dependencies.
- `tsconfig.json`: shared TypeScript settings for Node and browser code.
- `vite.config.ts`: browser bundle configuration.
- `vitest.config.ts`: unit and integration test configuration.
- `playwright.config.ts`: browser test configuration.
- `index.html`: Vite browser entry.
- `src/shared/types.ts`: shared API and UI types.
- `src/shared/errors.ts`: structured API errors and helpers.
- `src/shared/security.ts`: token and request header constants.
- `src/server/session.ts`: preview session creation and mode detection.
- `src/server/path-utils.ts`: realpath-based root containment checks.
- `src/server/file-tree.ts`: Markdown file scanning and default document selection.
- `src/server/http-server.ts`: static asset serving and `/api/*` routes.
- `src/server/events.ts`: single-file watcher and SSE event stream.
- `src/cli/args.ts`: argument parsing.
- `src/cli/index.ts`: executable CLI entry.
- `src/web/main.tsx`: React entry.
- `src/web/App.tsx`: top-level app state and layout switching.
- `src/web/api-client.ts`: token-aware browser API client.
- `src/web/markdown/detect.ts`: content detection for Mermaid and math.
- `src/web/markdown/sanitize.ts`: rehype sanitize schema.
- `src/web/components/FileTree.tsx`: directory file tree.
- `src/web/components/Outline.tsx`: heading outline.
- `src/web/components/MarkdownView.tsx`: Markdown rendering, code highlighting, Mermaid, math.
- `src/web/components/ErrorView.tsx`: full-page and panel errors.
- `src/web/styles.css`: restrained document browser styling.
- `tests/shared/*.test.ts`: shared type and error tests.
- `tests/server/*.test.ts`: filesystem, server API, and SSE tests.
- `tests/cli/*.test.ts`: CLI parser and launch tests.
- `tests/web/*.test.tsx`: browser component tests.
- `tests/e2e/mdreview.spec.ts`: Playwright flows.
- `tests/fixtures/docs/`: Markdown fixture tree.

## Implementation Tasks

### Task 1: Project Scaffold

**Files:**
- Create: `package.json`
- Create: `tsconfig.json`
- Create: `vite.config.ts`
- Create: `vitest.config.ts`
- Create: `playwright.config.ts`
- Create: `index.html`
- Create: `src/web/main.tsx`
- Create: `tests/smoke.test.ts`
- Modify: `.gitignore`

- [ ] **Step 1: Create package and toolchain files**

Write these baseline files. This step has no failing business test because it establishes the test runner and build tools.

```json
{
  "name": "mdreview",
  "version": "0.1.0",
  "type": "module",
  "private": true,
  "bin": {
    "mdreview": "./dist/node/index.js"
  },
  "scripts": {
    "dev": "tsx src/cli/index.ts",
    "build:web": "vite build",
    "build:node": "tsup src/cli/index.ts --format esm --dts --out-dir dist/node",
    "build": "npm run build:web && npm run build:node",
    "test": "vitest run",
    "test:watch": "vitest",
    "test:e2e": "playwright test",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "chokidar": "^4.0.0",
    "highlight.js": "^11.0.0",
    "katex": "^0.16.0",
    "mermaid": "^11.0.0",
    "open": "^10.0.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "react-markdown": "^10.0.0",
    "rehype-highlight": "^7.0.0",
    "rehype-katex": "^7.0.0",
    "rehype-raw": "^7.0.0",
    "rehype-sanitize": "^6.0.0",
    "remark-gfm": "^4.0.0",
    "remark-math": "^6.0.0"
  },
  "devDependencies": {
    "@playwright/test": "^1.0.0",
    "@testing-library/jest-dom": "^6.0.0",
    "@testing-library/react": "^16.0.0",
    "@vitejs/plugin-react": "^5.0.0",
    "@types/node": "^22.0.0",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "jsdom": "^26.0.0",
    "tsup": "^8.0.0",
    "tsx": "^4.0.0",
    "typescript": "^5.0.0",
    "unified": "^11.0.0",
    "vite": "^7.0.0",
    "vitest": "^3.0.0"
  }
}
```

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "jsx": "react-jsx",
    "strict": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true
  },
  "include": ["src", "tests", "*.config.ts"]
}
```

```ts
// vite.config.ts
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [react()],
  build: {
    outDir: "dist/client",
    emptyOutDir: true
  }
});
```

```ts
// vitest.config.ts
import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [react()],
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["tests/setup.ts"],
    include: ["tests/**/*.test.ts", "tests/**/*.test.tsx"]
  }
});
```

```ts
// playwright.config.ts
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "tests/e2e",
  timeout: 30_000,
  use: {
    ...devices["Desktop Chrome"],
    viewport: { width: 1280, height: 800 }
  }
});
```

```html
<!-- index.html -->
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>mdreview</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/web/main.tsx"></script>
  </body>
</html>
```

- [ ] **Step 2: Add minimal React entry and test setup**

```ts
// tests/setup.ts
import "@testing-library/jest-dom/vitest";
```

```ts
// tests/smoke.test.ts
import { describe, expect, it } from "vitest";

describe("tooling", () => {
  it("runs the test suite", () => {
    expect(true).toBe(true);
  });
});
```

```tsx
// src/web/main.tsx
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
import "./styles.css";

createRoot(document.getElementById("root") as HTMLElement).render(
  <StrictMode>
    <App />
  </StrictMode>
);
```

```tsx
// src/web/App.tsx
export function App() {
  return <main className="app-shell">mdreview</main>;
}
```

```css
/* src/web/styles.css */
:root {
  color: #1f2937;
  background: #f8fafc;
  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}

body {
  margin: 0;
}

.app-shell {
  min-height: 100vh;
}
```

- [ ] **Step 3: Install dependencies and verify tooling**

Run:

```bash
npm install
npm run typecheck
npm test
npm run build
```

Expected:

```text
No TypeScript errors.
PASS tests/smoke.test.ts
dist/client and dist/node are created by the build.
```

- [ ] **Step 4: Commit scaffold**

```bash
git add package.json package-lock.json tsconfig.json vite.config.ts vitest.config.ts playwright.config.ts index.html src tests .gitignore
git commit -m "chore: scaffold mdreview project"
```

### Task 2: Shared Contracts, Errors, and Token Constants

**Files:**
- Create: `src/shared/types.ts`
- Create: `src/shared/errors.ts`
- Create: `src/shared/security.ts`
- Test: `tests/shared/errors.test.ts`

- [ ] **Step 1: Write failing shared error tests**

```ts
// tests/shared/errors.test.ts
import { describe, expect, it } from "vitest";
import { apiError, isApiError } from "../../src/shared/errors";

describe("shared API errors", () => {
  it("creates a stable structured error body", () => {
    expect(apiError("FILE_NOT_FOUND", "File not found")).toEqual({
      error: {
        code: "FILE_NOT_FOUND",
        message: "File not found"
      }
    });
  });

  it("recognizes API error payloads", () => {
    expect(isApiError({ error: { code: "UNAUTHORIZED", message: "Bad token" } })).toBe(true);
    expect(isApiError({ code: "UNAUTHORIZED", message: "Bad token" })).toBe(false);
  });
});
```

- [ ] **Step 2: Run the shared tests and verify failure**

Run:

```bash
npm test -- tests/shared/errors.test.ts
```

Expected:

```text
FAIL tests/shared/errors.test.ts
Cannot find module '../../src/shared/errors'
```

- [ ] **Step 3: Implement shared contracts and helpers**

```ts
// src/shared/types.ts
export type PreviewMode = "file" | "directory";

export type FileNode = {
  type: "file" | "directory";
  name: string;
  path: string;
  children?: FileNode[];
};

export type SessionResponse = {
  mode: PreviewMode;
  rootName: string;
  defaultDocument: string | null;
};

export type DocumentResponse = {
  path: string;
  name: string;
  mtime: number;
  content: string;
};

export type ApiErrorCode =
  | "BAD_REQUEST"
  | "UNAUTHORIZED"
  | "FORBIDDEN"
  | "NOT_FOUND"
  | "FILE_NOT_FOUND"
  | "READ_FAILED"
  | "PORT_IN_USE";

export type ApiErrorBody = {
  error: {
    code: ApiErrorCode;
    message: string;
  };
};

export type FileChangedEvent = {
  type: "document:changed";
  path: string;
  mtime: number;
};
```

```ts
// src/shared/errors.ts
import type { ApiErrorBody, ApiErrorCode } from "./types";

export function apiError(code: ApiErrorCode, message: string): ApiErrorBody {
  return { error: { code, message } };
}

export function isApiError(value: unknown): value is ApiErrorBody {
  if (!value || typeof value !== "object") return false;
  const maybe = value as { error?: { code?: unknown; message?: unknown } };
  return typeof maybe.error?.code === "string" && typeof maybe.error.message === "string";
}
```

```ts
// src/shared/security.ts
export const API_TOKEN_HEADER = "x-mdreview-token";

export function createToken(bytes: Uint8Array): string {
  return Array.from(bytes, (value) => value.toString(16).padStart(2, "0")).join("");
}
```

- [ ] **Step 4: Verify shared tests pass**

Run:

```bash
npm test -- tests/shared/errors.test.ts
```

Expected:

```text
PASS tests/shared/errors.test.ts
```

- [ ] **Step 5: Commit shared contracts**

```bash
git add src/shared tests/shared
git commit -m "feat: add shared API contracts"
```

### Task 3: Filesystem Boundaries, Markdown Tree, and Default Document Selection

**Files:**
- Create: `src/server/session.ts`
- Create: `src/server/path-utils.ts`
- Create: `src/server/file-tree.ts`
- Test: `tests/server/file-tree.test.ts`

- [ ] **Step 1: Write failing filesystem tests**

```ts
// tests/server/file-tree.test.ts
import { mkdtemp, mkdir, realpath, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { assertInsideRoot } from "../../src/server/path-utils";
import { findRootReadme, listMarkdownFiles, selectDefaultDocument } from "../../src/server/file-tree";

async function makeFixture() {
  const root = await mkdtemp(path.join(tmpdir(), "mdreview-"));
  await writeFile(path.join(root, "readme.MD"), "# Root");
  await mkdir(path.join(root, "docs"));
  await writeFile(path.join(root, "docs", "guide.markdown"), "# Guide");
  await mkdir(path.join(root, "node_modules"));
  await writeFile(path.join(root, "node_modules", "ignored.md"), "# Ignored");
  await writeFile(path.join(root, "notes.txt"), "Not markdown");
  return root;
}

describe("file tree", () => {
  it("lists only Markdown files and skips heavy directories", async () => {
    const root = await makeFixture();
    const tree = await listMarkdownFiles(root);
    expect(JSON.stringify(tree)).toContain("readme.MD");
    expect(JSON.stringify(tree)).toContain("guide.markdown");
    expect(JSON.stringify(tree)).not.toContain("ignored.md");
    expect(JSON.stringify(tree)).not.toContain("notes.txt");
  });

  it("selects README before sorted fallback documents", async () => {
    const root = await makeFixture();
    const tree = await listMarkdownFiles(root);
    expect(selectDefaultDocument(tree)).toBe("readme.MD");
  });

  it("finds a root README without requiring a recursive tree scan", async () => {
    const root = await makeFixture();
    await expect(findRootReadme(root)).resolves.toBe("readme.MD");
  });

  it("rejects traversal outside the root using real paths", async () => {
    const root = await makeFixture();
    await writeFile(path.join(root, "..", "outside.md"), "# Outside");
    const rootReal = await realpath(root);
    await expect(assertInsideRoot(rootReal, "../outside.md")).rejects.toThrow("Path escapes preview root");
  });
});
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
npm test -- tests/server/file-tree.test.ts
```

Expected:

```text
FAIL tests/server/file-tree.test.ts
Cannot find module '../../src/server/path-utils'
```

- [ ] **Step 3: Implement path containment**

```ts
// src/server/path-utils.ts
import { realpath } from "node:fs/promises";
import path from "node:path";

export async function assertInsideRoot(rootRealPath: string, relativePath: string): Promise<string> {
  const resolved = path.resolve(rootRealPath, relativePath);
  const real = await realpath(resolved);
  const relative = path.relative(rootRealPath, real);
  if (relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative))) {
    return real;
  }
  throw new Error("Path escapes preview root");
}

export function toRelativePath(rootRealPath: string, absolutePath: string): string {
  return path.relative(rootRealPath, absolutePath).split(path.sep).join("/");
}
```

- [ ] **Step 4: Implement session and file tree utilities**

```ts
// src/server/session.ts
import { randomBytes } from "node:crypto";
import { realpath, stat } from "node:fs/promises";
import path from "node:path";
import { createToken } from "../shared/security";
import type { PreviewMode } from "../shared/types";

export type PreviewSession = {
  mode: PreviewMode;
  rootPath: string;
  rootRealPath: string;
  rootName: string;
  token: string;
};

export async function createPreviewSession(inputPath: string): Promise<PreviewSession> {
  const rootPath = path.resolve(inputPath);
  const stats = await stat(rootPath);
  const mode: PreviewMode = stats.isDirectory() ? "directory" : stats.isFile() ? "file" : "directory";
  if (!stats.isDirectory() && !stats.isFile()) {
    throw new Error("Path must be a file or directory");
  }
  const rootRealPath = await realpath(rootPath);
  return {
    mode,
    rootPath,
    rootRealPath,
    rootName: path.basename(rootPath),
    token: createToken(randomBytes(24))
  };
}
```

```ts
// src/server/file-tree.ts
import { readdir, stat } from "node:fs/promises";
import path from "node:path";
import type { FileNode } from "../shared/types";

const SKIPPED_DIRECTORIES = new Set([".git", "node_modules", "dist", "build"]);
const README_ORDER = ["readme.md", "readme.markdown"];

export function isMarkdownPath(filePath: string): boolean {
  const lower = filePath.toLowerCase();
  return lower.endsWith(".md") || lower.endsWith(".markdown");
}

export async function listMarkdownFiles(rootPath: string, relativePath = ""): Promise<FileNode[]> {
  const absolute = path.join(rootPath, relativePath);
  const entries = await readdir(absolute, { withFileTypes: true });
  const nodes: FileNode[] = [];

  for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" }))) {
    const childRelative = path.join(relativePath, entry.name).split(path.sep).join("/");
    if (entry.isDirectory()) {
      if (SKIPPED_DIRECTORIES.has(entry.name)) continue;
      const children = await listMarkdownFiles(rootPath, childRelative);
      if (children.length > 0) {
        nodes.push({ type: "directory", name: entry.name, path: childRelative, children });
      }
      continue;
    }
    if (entry.isFile() && isMarkdownPath(entry.name)) {
      const absoluteChild = path.join(rootPath, childRelative);
      const stats = await stat(absoluteChild);
      if (stats.isFile()) nodes.push({ type: "file", name: entry.name, path: childRelative });
    }
  }

  return nodes;
}

export function flattenFiles(nodes: FileNode[]): FileNode[] {
  return nodes.flatMap((node) => (node.type === "file" ? [node] : flattenFiles(node.children ?? [])));
}

export async function findRootReadme(rootPath: string): Promise<string | null> {
  const entries = await readdir(rootPath, { withFileTypes: true });
  for (const expected of README_ORDER) {
    const match = entries.find((entry) => entry.isFile() && entry.name.toLowerCase() === expected);
    if (match) return match.name;
  }
  return null;
}

export function selectDefaultDocument(nodes: FileNode[]): string | null {
  const files = flattenFiles(nodes);
  const readme = files.find((file) => README_ORDER.includes(file.path.toLowerCase()));
  if (readme) return readme.path;
  const first = [...files].sort((a, b) => a.path.localeCompare(b.path, undefined, { sensitivity: "base" }))[0];
  return first?.path ?? null;
}
```

- [ ] **Step 5: Verify filesystem tests pass**

Run:

```bash
npm test -- tests/server/file-tree.test.ts
```

Expected:

```text
PASS tests/server/file-tree.test.ts
```

- [ ] **Step 6: Commit filesystem utilities**

```bash
git add src/server tests/server/file-tree.test.ts
git commit -m "feat: add markdown file discovery"
```

### Task 4: Token-Protected Preview Server APIs

**Files:**
- Create: `src/server/http-server.ts`
- Test: `tests/server/http-server.test.ts`

- [ ] **Step 1: Write failing API integration tests**

```ts
// tests/server/http-server.test.ts
import { mkdir, mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { API_TOKEN_HEADER } from "../../src/shared/security";
import { createPreviewSession } from "../../src/server/session";
import { startPreviewServer, type StartedPreviewServer } from "../../src/server/http-server";

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
```

- [ ] **Step 2: Run API tests and verify failure**

Run:

```bash
npm test -- tests/server/http-server.test.ts
```

Expected:

```text
FAIL tests/server/http-server.test.ts
Cannot find module '../../src/server/http-server'
```

- [ ] **Step 3: Implement token-protected HTTP server**

```ts
// src/server/http-server.ts
import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { readFile, realpath, stat } from "node:fs/promises";
import path from "node:path";
import type { PreviewSession } from "./session";
import { API_TOKEN_HEADER } from "../shared/security";
import { apiError } from "../shared/errors";
import { assertInsideRoot } from "./path-utils";
import { findRootReadme, listMarkdownFiles } from "./file-tree";

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
  const realPath = session.mode === "file"
    ? session.rootRealPath
    : await assertInsideRoot(session.rootRealPath, relativePath);
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
```

- [ ] **Step 4: Verify API tests pass**

Run:

```bash
npm test -- tests/server/http-server.test.ts
```

Expected:

```text
PASS tests/server/http-server.test.ts
```

- [ ] **Step 5: Commit preview server APIs**

```bash
git add src/server/http-server.ts tests/server/http-server.test.ts
git commit -m "feat: add preview server APIs"
```

### Task 5: CLI Argument Parsing and Launch Flow

**Files:**
- Create: `src/cli/args.ts`
- Modify: `src/cli/index.ts`
- Test: `tests/cli/args.test.ts`

- [ ] **Step 1: Write failing CLI parser tests**

```ts
// tests/cli/args.test.ts
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
```

- [ ] **Step 2: Run CLI tests and verify failure**

Run:

```bash
npm test -- tests/cli/args.test.ts
```

Expected:

```text
FAIL tests/cli/args.test.ts
Cannot find module '../../src/cli/args'
```

- [ ] **Step 3: Implement CLI parser and executable entry**

```ts
// src/cli/args.ts
export type CliOptions = {
  action: "serve";
  path: string;
  port?: number;
  openBrowser: boolean;
} | {
  action: "help";
} | {
  action: "version";
};

export const HELP_TEXT = "Usage: mdreview <file-or-directory> [--port <number>] [--no-open]";
export const VERSION = "0.1.0";

export function parseArgs(argv: string[]): CliOptions {
  if (argv.includes("--help")) {
    return { action: "help" };
  }
  if (argv.includes("--version")) {
    return { action: "version" };
  }

  let inputPath: string | undefined;
  let port: number | undefined;
  let openBrowser = true;

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--no-open") {
      openBrowser = false;
      continue;
    }
    if (arg === "--port") {
      const value = argv[index + 1];
      if (!value || Number.isNaN(Number(value))) throw new Error("--port requires a number");
      port = Number(value);
      index += 1;
      continue;
    }
    if (!arg.startsWith("-") && !inputPath) {
      inputPath = arg;
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  if (!inputPath) throw new Error("Usage: mdreview <file-or-directory>");
  return { action: "serve", path: inputPath, port, openBrowser };
}
```

```ts
// src/cli/index.ts
#!/usr/bin/env node
import open from "open";
import { HELP_TEXT, VERSION, parseArgs } from "./args";
import { createPreviewSession } from "../server/session";
import { startPreviewServer } from "../server/http-server";

async function main() {
  try {
    const options = parseArgs(process.argv.slice(2));
    if (options.action === "help") {
      console.log(HELP_TEXT);
      return;
    }
    if (options.action === "version") {
      console.log(VERSION);
      return;
    }
    const session = await createPreviewSession(options.path);
    const server = await startPreviewServer({ session, port: options.port });
    const url = `${server.url}/#token=${session.token}`;
    console.log(`mdreview preview: ${url}`);
    if (options.openBrowser) {
      await open(url).catch(() => {
        console.warn(`Could not open browser automatically. Open this URL manually: ${url}`);
      });
    }
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}

void main();
```

- [ ] **Step 4: Verify CLI tests pass**

Run:

```bash
npm test -- tests/cli/args.test.ts
npm run typecheck
```

Expected:

```text
PASS tests/cli/args.test.ts
No TypeScript errors.
```

- [ ] **Step 5: Commit CLI launch flow**

```bash
git add src/cli tests/cli
git commit -m "feat: add mdreview CLI"
```

### Task 6: Browser API Client and Document Browser Layout

**Files:**
- Create: `src/web/api-client.ts`
- Modify: `src/web/App.tsx`
- Create: `src/web/components/FileTree.tsx`
- Create: `src/web/components/Outline.tsx`
- Create: `src/web/components/ErrorView.tsx`
- Modify: `src/web/styles.css`
- Test: `tests/web/App.test.tsx`

- [ ] **Step 1: Write failing browser layout tests**

```tsx
// tests/web/App.test.tsx
import { render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { App } from "../../src/web/App";

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("App layout", () => {
  it("shows file tree in directory mode", async () => {
    window.history.pushState(null, "", "/#token=test-token");
    vi.stubGlobal("fetch", vi.fn(async (url: string) => {
      if (url.endsWith("/api/session")) {
        return Response.json({ mode: "directory", rootName: "docs", defaultDocument: "README.md" });
      }
      if (url.endsWith("/api/files")) {
        return Response.json([{ type: "file", name: "README.md", path: "README.md" }]);
      }
      return Response.json({ path: "README.md", name: "README.md", mtime: 1, content: "# Hello" });
    }));

    render(<App />);
    await waitFor(() => expect(screen.getByText("README.md")).toBeInTheDocument());
    expect(screen.getByLabelText("Markdown files")).toBeInTheDocument();
  });

  it("hides file tree in single-file mode", async () => {
    window.history.pushState(null, "", "/#token=test-token");
    vi.stubGlobal("fetch", vi.fn(async (url: string) => {
      if (url.endsWith("/api/session")) {
        return Response.json({ mode: "file", rootName: "README.md", defaultDocument: "README.md" });
      }
      return Response.json({ path: "README.md", name: "README.md", mtime: 1, content: "# Hello" });
    }));

    render(<App />);
    await waitFor(() => expect(screen.getByText("README.md")).toBeInTheDocument());
    expect(screen.queryByLabelText("Markdown files")).not.toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run browser tests and verify failure**

Run:

```bash
npm test -- tests/web/App.test.tsx
```

Expected:

```text
FAIL tests/web/App.test.tsx
Unable to find an element with the text: README.md
```

- [ ] **Step 3: Implement token-aware API client**

```ts
// src/web/api-client.ts
import { API_TOKEN_HEADER } from "../shared/security";
import type { DocumentResponse, FileNode, SessionResponse } from "../shared/types";

export function readTokenFromLocation(hash = window.location.hash): string | null {
  const params = new URLSearchParams(hash.replace(/^#/, ""));
  return params.get("token");
}

export class ApiClient {
  constructor(private readonly token: string) {}

  private async getJson<T>(path: string): Promise<T> {
    const response = await fetch(path, { headers: { [API_TOKEN_HEADER]: this.token } });
    if (!response.ok) throw new Error(`Request failed: ${response.status}`);
    return response.json() as Promise<T>;
  }

  session() {
    return this.getJson<SessionResponse>("/api/session");
  }

  files() {
    return this.getJson<FileNode[]>("/api/files");
  }

  document(path: string) {
    return this.getJson<DocumentResponse>(`/api/document?path=${encodeURIComponent(path)}`);
  }
}
```

- [ ] **Step 4: Implement layout components**

```tsx
// src/web/components/FileTree.tsx
import type { FileNode } from "../../shared/types";

type Props = {
  nodes: FileNode[];
  currentPath: string | null;
  onSelect: (path: string) => void;
};

export function FileTree({ nodes, currentPath, onSelect }: Props) {
  return (
    <nav className="file-tree" aria-label="Markdown files">
      {nodes.map((node) => (
        <TreeNode key={node.path} node={node} currentPath={currentPath} onSelect={onSelect} />
      ))}
    </nav>
  );
}

function TreeNode({ node, currentPath, onSelect }: { node: FileNode; currentPath: string | null; onSelect: (path: string) => void }) {
  if (node.type === "directory") {
    return (
      <div className="tree-directory">
        <div className="tree-directory-name">{node.name}</div>
        <div className="tree-children">
          {(node.children ?? []).map((child) => (
            <TreeNode key={child.path} node={child} currentPath={currentPath} onSelect={onSelect} />
          ))}
        </div>
      </div>
    );
  }
  return (
    <button className={node.path === currentPath ? "tree-file active" : "tree-file"} onClick={() => onSelect(node.path)}>
      {node.name}
    </button>
  );
}
```

```tsx
// src/web/components/Outline.tsx
export type OutlineItem = {
  id: string;
  text: string;
  depth: number;
};

export function Outline({ items }: { items: OutlineItem[] }) {
  return (
    <aside className="outline" aria-label="On this page">
      {items.map((item) => (
        <a key={item.id} className={`outline-item depth-${item.depth}`} href={`#${item.id}`}>
          {item.text}
        </a>
      ))}
    </aside>
  );
}
```

```tsx
// src/web/components/ErrorView.tsx
export function ErrorView({ title, detail }: { title: string; detail: string }) {
  return (
    <section className="error-view" role="alert">
      <h1>{title}</h1>
      <p>{detail}</p>
    </section>
  );
}
```

- [ ] **Step 5: Wire App state**

```tsx
// src/web/App.tsx
import { useEffect, useMemo, useState } from "react";
import type { DocumentResponse, FileNode, SessionResponse } from "../shared/types";
import { ApiClient, readTokenFromLocation } from "./api-client";
import { ErrorView } from "./components/ErrorView";
import { FileTree } from "./components/FileTree";
import { Outline, type OutlineItem } from "./components/Outline";

function extractOutline(content: string): OutlineItem[] {
  return content
    .split("\n")
    .map((line) => /^(#{1,6})\s+(.+)$/.exec(line))
    .filter((match): match is RegExpExecArray => Boolean(match))
    .map((match) => ({
      depth: match[1].length,
      text: match[2],
      id: match[2].toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
    }));
}

function firstMarkdownPath(nodes: FileNode[]): string | null {
  for (const node of nodes) {
    if (node.type === "file") return node.path;
    const childPath = firstMarkdownPath(node.children ?? []);
    if (childPath) return childPath;
  }
  return null;
}

export function App() {
  const token = readTokenFromLocation();
  const client = useMemo(() => (token ? new ApiClient(token) : null), [token]);
  const [session, setSession] = useState<SessionResponse | null>(null);
  const [files, setFiles] = useState<FileNode[]>([]);
  const [document, setDocument] = useState<DocumentResponse | null>(null);
  const [error, setError] = useState<string | null>(token ? null : "Missing preview session token");

  useEffect(() => {
    if (!client) return;
    client.session()
      .then(async (nextSession) => {
        setSession(nextSession);
        let loadedFiles: FileNode[] = [];
        if (nextSession.mode === "directory") {
          loadedFiles = await client.files();
          setFiles(loadedFiles);
        }
        const defaultPath = nextSession.defaultDocument ?? firstMarkdownPath(loadedFiles);
        if (defaultPath) setDocument(await client.document(defaultPath));
      })
      .catch((reason) => setError(reason instanceof Error ? reason.message : String(reason)));
  }, [client]);

  async function selectDocument(path: string) {
    if (!client) return;
    setDocument(await client.document(path));
  }

  if (error) return <ErrorView title="Preview session unavailable" detail={error} />;
  if (!session || !document) return <main className="app-shell loading">Loading...</main>;

  const outline = extractOutline(document.content);

  return (
    <main className={session.mode === "directory" ? "app-shell directory-mode" : "app-shell file-mode"}>
      {session.mode === "directory" && <FileTree nodes={files} currentPath={document.path} onSelect={selectDocument} />}
      <section className="document-pane">
        <header className="document-header">{document.name}</header>
        <article className="markdown-body">{document.content}</article>
      </section>
      <Outline items={outline} />
    </main>
  );
}
```

- [ ] **Step 6: Add layout CSS**

```css
/* append to src/web/styles.css */
.app-shell {
  display: grid;
  min-height: 100vh;
}

.directory-mode {
  grid-template-columns: 260px minmax(0, 1fr) 220px;
}

.file-mode {
  grid-template-columns: minmax(0, 1fr) 220px;
}

.file-tree,
.outline {
  border-color: #e5e7eb;
  background: #ffffff;
  overflow: auto;
  padding: 16px;
}

.file-tree {
  border-right: 1px solid #e5e7eb;
}

.outline {
  border-left: 1px solid #e5e7eb;
}

.document-pane {
  min-width: 0;
  overflow: auto;
  background: #ffffff;
}

.document-header {
  border-bottom: 1px solid #e5e7eb;
  padding: 12px 24px;
  font-weight: 600;
}

.markdown-body {
  max-width: 860px;
  margin: 0 auto;
  padding: 32px 40px 64px;
}

.tree-file {
  display: block;
  width: 100%;
  border: 0;
  background: transparent;
  color: #374151;
  cursor: pointer;
  padding: 6px 8px;
  text-align: left;
}

.tree-file.active {
  background: #e0f2fe;
  color: #075985;
}
```

- [ ] **Step 7: Verify layout tests pass**

Run:

```bash
npm test -- tests/web/App.test.tsx
```

Expected:

```text
PASS tests/web/App.test.tsx
```

- [ ] **Step 8: Commit browser layout**

```bash
git add src/web tests/web
git commit -m "feat: add browser preview layout"
```

### Task 7: Safe Markdown Rendering, GFM, Code Highlighting, and Outline Anchors

**Files:**
- Create: `src/web/markdown/sanitize.ts`
- Modify: `src/web/components/MarkdownView.tsx`
- Modify: `src/web/App.tsx`
- Test: `tests/web/MarkdownView.test.tsx`

- [ ] **Step 1: Write failing Markdown rendering tests**

```tsx
// tests/web/MarkdownView.test.tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { MarkdownView } from "../../src/web/components/MarkdownView";

describe("MarkdownView", () => {
  it("renders headings with stable anchors and GFM task lists", () => {
    render(<MarkdownView content={"# Hello World\n\n- [x] shipped"} onOutline={() => undefined} />);
    expect(screen.getByRole("heading", { name: "Hello World" })).toHaveAttribute("id", "hello-world");
    expect(screen.getByRole("checkbox")).toBeChecked();
  });

  it("does not execute script or event handler HTML", () => {
    const alertSpy = vi.spyOn(window, "alert").mockImplementation(() => undefined);
    render(<MarkdownView content={'<img src=x onerror="alert(1)"><script>alert(2)</script>'} onOutline={() => undefined} />);
    expect(alertSpy).not.toHaveBeenCalled();
    expect(document.querySelector("script")).toBeNull();
    expect(document.querySelector("[onerror]")).toBeNull();
  });
});
```

- [ ] **Step 2: Run Markdown tests and verify failure**

Run:

```bash
npm test -- tests/web/MarkdownView.test.tsx
```

Expected:

```text
FAIL tests/web/MarkdownView.test.tsx
Cannot find module '../../src/web/components/MarkdownView'
```

- [ ] **Step 3: Implement sanitize schema and MarkdownView**

```ts
// src/web/markdown/sanitize.ts
import { defaultSchema } from "rehype-sanitize";

export const markdownSanitizeSchema = {
  ...defaultSchema,
  attributes: {
    ...defaultSchema.attributes,
    code: [["className", /^language-[\w-]+$/]],
    span: [["className", /^hljs-.*$/]],
    input: [["type", "checkbox"], ["checked"], ["disabled"]]
  }
};
```

```tsx
// src/web/components/MarkdownView.tsx
import { useEffect, useMemo } from "react";
import ReactMarkdown from "react-markdown";
import rehypeHighlight from "rehype-highlight";
import rehypeRaw from "rehype-raw";
import rehypeSanitize from "rehype-sanitize";
import remarkGfm from "remark-gfm";
import { markdownSanitizeSchema } from "../markdown/sanitize";
import type { OutlineItem } from "./Outline";
import "highlight.js/styles/github.css";

function slugify(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}

export function outlineFromMarkdown(content: string): OutlineItem[] {
  return content
    .split("\n")
    .map((line) => /^(#{1,6})\s+(.+)$/.exec(line))
    .filter((match): match is RegExpExecArray => Boolean(match))
    .map((match) => ({ depth: match[1].length, text: match[2], id: slugify(match[2]) }));
}

export function MarkdownView({ content, onOutline }: { content: string; onOutline: (items: OutlineItem[]) => void }) {
  const outline = useMemo(() => outlineFromMarkdown(content), [content]);
  useEffect(() => {
    onOutline(outline);
  }, [onOutline, outline]);

  return (
    <ReactMarkdown
      remarkPlugins={[remarkGfm]}
      rehypePlugins={[rehypeRaw, [rehypeSanitize, markdownSanitizeSchema], rehypeHighlight]}
      components={{
        h1: ({ children }) => <h1 id={slugify(String(children))}>{children}</h1>,
        h2: ({ children }) => <h2 id={slugify(String(children))}>{children}</h2>,
        h3: ({ children }) => <h3 id={slugify(String(children))}>{children}</h3>
      }}
    >
      {content}
    </ReactMarkdown>
  );
}
```

- [ ] **Step 4: Replace raw content in App with MarkdownView**

```tsx
// in src/web/App.tsx imports
import { MarkdownView } from "./components/MarkdownView";

// inside App component state
const [outline, setOutline] = useState<OutlineItem[]>([]);

// replace extractOutline usage and article content
<article className="markdown-body">
  <MarkdownView content={document.content} onOutline={setOutline} />
</article>
<Outline items={outline} />
```

- [ ] **Step 5: Verify Markdown tests pass**

Run:

```bash
npm test -- tests/web/MarkdownView.test.tsx tests/web/App.test.tsx
```

Expected:

```text
PASS tests/web/MarkdownView.test.tsx
PASS tests/web/App.test.tsx
```

- [ ] **Step 6: Commit safe Markdown rendering**

```bash
git add src/web tests/web/MarkdownView.test.tsx
git commit -m "feat: render safe markdown"
```

### Task 8: Dynamic Mermaid and Math Rendering

**Files:**
- Create: `src/web/markdown/detect.ts`
- Modify: `src/web/components/MarkdownView.tsx`
- Test: `tests/web/markdown-detect.test.ts`
- Test: `tests/web/MarkdownView.dynamic.test.tsx`

- [ ] **Step 1: Write failing content detection tests**

```ts
// tests/web/markdown-detect.test.ts
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
```

- [ ] **Step 2: Run detection tests and verify failure**

Run:

```bash
npm test -- tests/web/markdown-detect.test.ts
```

Expected:

```text
FAIL tests/web/markdown-detect.test.ts
Cannot find module '../../src/web/markdown/detect'
```

- [ ] **Step 3: Implement detection utilities**

```ts
// src/web/markdown/detect.ts
export function containsMermaid(content: string): boolean {
  return /```mermaid[\s\S]*?```/i.test(content);
}

export function containsMath(content: string): boolean {
  return /\$\$[\s\S]+?\$\$/.test(content) || /(^|[^\\])\$[^$\n]+\$/.test(content);
}
```

- [ ] **Step 4: Extend MarkdownView for dynamic plugins**

```tsx
// src/web/components/MarkdownView.tsx additions
// update the existing React import to include useState
import { useEffect, useMemo, useState } from "react";
import type { PluggableList } from "unified";
import { containsMath, containsMermaid } from "../markdown/detect";
import "katex/dist/katex.min.css";

type DynamicPlugins = {
  remarkMath?: PluggableList[number];
  rehypeKatex?: PluggableList[number];
};

function MermaidBlock({ code }: { code: string }) {
  const [svg, setSvg] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    import("mermaid")
      .then(async ({ default: mermaid }) => {
        mermaid.initialize({ startOnLoad: false, securityLevel: "strict" });
        const result = await mermaid.render(`mermaid-${crypto.randomUUID()}`, code);
        if (!cancelled) setSvg(result.svg);
      })
      .catch((reason) => {
        if (!cancelled) setError(reason instanceof Error ? reason.message : String(reason));
      });
    return () => {
      cancelled = true;
    };
  }, [code]);

  if (error) return <pre className="render-error">{code}</pre>;
  if (!svg) return <pre className="render-pending">{code}</pre>;
  return <div className="mermaid-output" dangerouslySetInnerHTML={{ __html: svg }} />;
}

// inside MarkdownView before return
const [dynamicPlugins, setDynamicPlugins] = useState<DynamicPlugins>({});
useEffect(() => {
  let cancelled = false;
  if (!containsMath(content)) return;
  Promise.all([import("remark-math"), import("rehype-katex")]).then(([remarkMath, rehypeKatex]) => {
    if (!cancelled) setDynamicPlugins({ remarkMath: remarkMath.default, rehypeKatex: rehypeKatex.default });
  });
  return () => {
    cancelled = true;
  };
}, [content]);

const remarkPlugins: PluggableList = dynamicPlugins.remarkMath ? [remarkGfm, dynamicPlugins.remarkMath] : [remarkGfm];
const rehypePlugins: PluggableList = dynamicPlugins.rehypeKatex
  ? [rehypeRaw, [rehypeSanitize, markdownSanitizeSchema], rehypeHighlight, dynamicPlugins.rehypeKatex]
  : [rehypeRaw, [rehypeSanitize, markdownSanitizeSchema], rehypeHighlight];

// in ReactMarkdown props
remarkPlugins={remarkPlugins}
rehypePlugins={rehypePlugins}
components={{
  h1: ({ children }) => <h1 id={slugify(String(children))}>{children}</h1>,
  h2: ({ children }) => <h2 id={slugify(String(children))}>{children}</h2>,
  h3: ({ children }) => <h3 id={slugify(String(children))}>{children}</h3>,
  code({ className, children }) {
    const code = String(children).replace(/\n$/, "");
    if (/language-mermaid/i.test(className ?? "") && containsMermaid(`\`\`\`mermaid\n${code}\n\`\`\``)) {
      return <MermaidBlock code={code} />;
    }
    return <code className={className}>{children}</code>;
  }
}}
```

- [ ] **Step 5: Write dynamic rendering smoke tests**

```tsx
// tests/web/MarkdownView.dynamic.test.tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { MarkdownView } from "../../src/web/components/MarkdownView";

describe("MarkdownView dynamic rendering", () => {
  it("keeps Mermaid source visible while dynamic renderer loads", () => {
    render(<MarkdownView content={"```mermaid\ngraph TD\nA-->B\n```"} onOutline={() => undefined} />);
    expect(screen.getByText(/graph TD/)).toBeInTheDocument();
  });

  it("renders math content without blanking the document", () => {
    render(<MarkdownView content={"# Math\n\nEuler: $e^{i\\pi}+1=0$"} onOutline={() => undefined} />);
    expect(screen.getByRole("heading", { name: "Math" })).toBeInTheDocument();
  });
});
```

- [ ] **Step 6: Verify dynamic tests pass**

Run:

```bash
npm test -- tests/web/markdown-detect.test.ts tests/web/MarkdownView.dynamic.test.tsx tests/web/MarkdownView.test.tsx
```

Expected:

```text
PASS tests/web/markdown-detect.test.ts
PASS tests/web/MarkdownView.dynamic.test.tsx
PASS tests/web/MarkdownView.test.tsx
```

- [ ] **Step 7: Commit dynamic rendering**

```bash
git add src/web tests/web
git commit -m "feat: add dynamic mermaid and math rendering"
```

### Task 9: Single-File Watcher and SSE Auto Refresh

**Files:**
- Create: `src/server/events.ts`
- Modify: `src/server/http-server.ts`
- Modify: `src/web/api-client.ts`
- Modify: `src/web/App.tsx`
- Test: `tests/server/events.test.ts`

- [ ] **Step 1: Write failing watcher test**

```ts
// tests/server/events.test.ts
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { watchSingleFile } from "../../src/server/events";

describe("single-file watcher", () => {
  it("emits document:changed when the file changes", async () => {
    const root = await mkdtemp(path.join(tmpdir(), "mdreview-watch-"));
    const file = path.join(root, "README.md");
    await writeFile(file, "# One");

    const events: string[] = [];
    const watcher = watchSingleFile(file, (event) => events.push(event.type));
    await writeFile(file, "# Two");

    await new Promise((resolve) => setTimeout(resolve, 250));
    await watcher.close();

    expect(events).toContain("document:changed");
  });
});
```

- [ ] **Step 2: Run watcher test and verify failure**

Run:

```bash
npm test -- tests/server/events.test.ts
```

Expected:

```text
FAIL tests/server/events.test.ts
Cannot find module '../../src/server/events'
```

- [ ] **Step 3: Implement watcher and SSE helpers**

```ts
// src/server/events.ts
import { stat } from "node:fs/promises";
import type { ServerResponse } from "node:http";
import chokidar from "chokidar";
import type { FileChangedEvent } from "../shared/types";

export function writeSse(response: ServerResponse, event: FileChangedEvent) {
  response.write(`event: ${event.type}\n`);
  response.write(`data: ${JSON.stringify(event)}\n\n`);
}

export function watchSingleFile(filePath: string, onChange: (event: FileChangedEvent) => void) {
  const watcher = chokidar.watch(filePath, { ignoreInitial: true, awaitWriteFinish: { stabilityThreshold: 120, pollInterval: 40 } });
  watcher.on("change", async () => {
    const stats = await stat(filePath);
    onChange({ type: "document:changed", path: filePath, mtime: stats.mtimeMs });
  });
  return watcher;
}
```

- [ ] **Step 4: Add `/api/events` route**

In `src/server/http-server.ts`, store SSE clients for file mode and broadcast watcher events:

```ts
const eventClients = new Set<ServerResponse>();
const watcher = session.mode === "file"
  ? watchSingleFile(session.rootRealPath, (event) => {
      for (const client of eventClients) writeSse(client, event);
    })
  : null;

// inside API route handling
if (url.pathname === "/api/events") {
  response.writeHead(200, {
    "content-type": "text/event-stream",
    "cache-control": "no-store",
    connection: "keep-alive"
  });
  eventClients.add(response);
  request.on("close", () => eventClients.delete(response));
  return;
}

// replace the returned close implementation with this body
close: async () => {
  for (const client of eventClients) {
    client.end();
  }
  eventClients.clear();
  await watcher?.close();
  await new Promise<void>((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
}
```

- [ ] **Step 5: Add browser event subscription**

```ts
// src/web/api-client.ts addition
export function subscribeToDocumentEvents(token: string, onChange: () => void): () => void {
  const controller = new AbortController();

  void (async () => {
    const response = await fetch("/api/events", {
      headers: { [API_TOKEN_HEADER]: token },
      signal: controller.signal
    });
    if (!response.ok || !response.body) return;

    const reader = response.body.pipeThrough(new TextDecoderStream()).getReader();
    let buffer = "";
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      buffer += value;
      const messages = buffer.split("\n\n");
      buffer = messages.pop() ?? "";
      for (const message of messages) {
        if (message.includes("event: document:changed")) onChange();
      }
    }
  })().catch((error) => {
    if (!controller.signal.aborted) console.error(error);
  });

  return () => controller.abort();
}
```

In `src/web/App.tsx`, subscribe only for single-file mode:

```tsx
// in src/web/App.tsx imports
import { subscribeToDocumentEvents } from "./api-client";

useEffect(() => {
  if (!token || !client || session?.mode !== "file" || !document) return;
  return subscribeToDocumentEvents(token, () => {
    void client.document(document.path).then(setDocument).catch((reason) => {
      setError(reason instanceof Error ? reason.message : String(reason));
    });
  });
}, [token, client, session?.mode, document?.path]);
```

- [ ] **Step 6: Verify watcher tests pass**

Run:

```bash
npm test -- tests/server/events.test.ts tests/server/http-server.test.ts tests/web/App.test.tsx
```

Expected:

```text
PASS tests/server/events.test.ts
PASS tests/server/http-server.test.ts
PASS tests/web/App.test.tsx
```

- [ ] **Step 7: Commit watcher and auto refresh**

```bash
git add src/server src/web tests/server tests/web
git commit -m "feat: add single-file auto refresh"
```

### Task 10: End-to-End Browser Flows

**Files:**
- Create: `tests/fixtures/docs/README.md`
- Create: `tests/fixtures/docs/guide.md`
- Create: `tests/e2e/mdreview.spec.ts`
- Modify: `playwright.config.ts`

- [ ] **Step 1: Add fixture documents**

~~~markdown
<!-- tests/fixtures/docs/README.md -->
# Fixture Docs

- [x] Task list

```mermaid
graph TD
  A --> B
```

Inline math: $a^2 + b^2 = c^2$
~~~

~~~markdown
<!-- tests/fixtures/docs/guide.md -->
# Guide

## Install

Run the command.
~~~

- [ ] **Step 2: Write Playwright flow tests**

```ts
// tests/e2e/mdreview.spec.ts
import { expect, test } from "@playwright/test";
import path from "node:path";
import { createPreviewSession } from "../../src/server/session";
import { startPreviewServer, type StartedPreviewServer } from "../../src/server/http-server";

let server: StartedPreviewServer;

test.afterEach(async () => {
  await server?.close();
});

test("directory mode shows file tree, rendered document, and outline", async ({ page }) => {
  const root = path.resolve("tests/fixtures/docs");
  const session = await createPreviewSession(root);
  server = await startPreviewServer({ session, staticDir: path.resolve("dist/client") });

  await page.goto(`${server.url}/#token=${session.token}`);
  await expect(page.getByLabel("Markdown files")).toBeVisible();
  await expect(page.getByRole("heading", { name: "Fixture Docs" })).toBeVisible();
  await expect(page.getByLabel("On this page")).toContainText("Fixture Docs");
});

test("single-file mode hides file tree", async ({ page }) => {
  const file = path.resolve("tests/fixtures/docs/README.md");
  const session = await createPreviewSession(file);
  server = await startPreviewServer({ session, staticDir: path.resolve("dist/client") });

  await page.goto(`${server.url}/#token=${session.token}`);
  await expect(page.getByLabel("Markdown files")).toHaveCount(0);
  await expect(page.getByRole("heading", { name: "Fixture Docs" })).toBeVisible();
});
```

- [ ] **Step 3: Build and run E2E tests**

Run:

```bash
npm run build
npm run test:e2e
```

Expected:

```text
2 passed
```

- [ ] **Step 4: Commit E2E coverage**

```bash
git add tests/e2e tests/fixtures playwright.config.ts
git commit -m "test: add mdreview browser flows"
```

### Task 11: Error States, Performance Guardrails, and Final Verification

**Files:**
- Modify: `src/server/http-server.ts`
- Modify: `src/web/components/ErrorView.tsx`
- Modify: `src/web/styles.css`
- Create: `README.md`
- Test: `tests/server/security.test.ts`
- Test: `tests/web/ErrorView.test.tsx`

- [ ] **Step 1: Write security and error state tests**

```ts
// tests/server/security.test.ts
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { API_TOKEN_HEADER } from "../../src/shared/security";
import { createPreviewSession } from "../../src/server/session";
import { startPreviewServer, type StartedPreviewServer } from "../../src/server/http-server";

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
```

```tsx
// tests/web/ErrorView.test.tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { ErrorView } from "../../src/web/components/ErrorView";

describe("ErrorView", () => {
  it("renders actionable session errors", () => {
    render(<ErrorView title="Preview session unavailable" detail="Invalid preview session token. Re-run mdreview." />);
    expect(screen.getByRole("alert")).toHaveTextContent("Re-run mdreview");
  });
});
```

- [ ] **Step 2: Run final security tests**

Run:

```bash
npm test -- tests/server/security.test.ts tests/web/ErrorView.test.tsx
```

Expected:

```text
PASS tests/server/security.test.ts
PASS tests/web/ErrorView.test.tsx
```

- [ ] **Step 3: Add README usage**

~~~markdown
# mdreview

Lightweight local Markdown previewer.

## Usage

```bash
mdreview README.md
mdreview docs
mdreview docs --no-open
mdreview docs --port 4010
```

Single-file mode hides the file tree and refreshes automatically when the file changes. Directory mode shows Markdown files, the rendered document, and an outline.

The local server binds to `127.0.0.1` and protects file APIs with a per-session token.
~~~

- [ ] **Step 4: Run full verification**

Run:

```bash
npm run typecheck
npm test
npm run build
npm run test:e2e
```

Expected:

```text
No TypeScript errors.
All Vitest tests pass.
Build completes with dist/client and dist/node.
All Playwright tests pass.
```

- [ ] **Step 5: Commit final MVP hardening**

```bash
git add src tests README.md package.json package-lock.json
git commit -m "chore: verify mdreview MVP"
```

## Final Acceptance Checklist

- [ ] `mdreview README.md` starts a local preview and prints a tokenized URL.
- [ ] `mdreview docs` starts directory mode with file tree, rendered document, and outline.
- [ ] Single-file mode hides the file tree.
- [ ] Single-file changes trigger preview refresh.
- [ ] Missing or invalid API token returns `401`.
- [ ] Traversal outside the preview root is blocked.
- [ ] Markdown with scripts or event handler attributes does not execute.
- [ ] Mermaid and math content do not blank the document.
- [ ] `npm run typecheck`, `npm test`, `npm run build`, and `npm run test:e2e` pass.
