import { mkdir, mkdtemp, realpath, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { findRootReadme, listMarkdownFiles, selectDefaultDocument } from "../../src/server/file-tree";
import { assertInsideRoot } from "../../src/server/path-utils";

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
