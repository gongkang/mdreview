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
