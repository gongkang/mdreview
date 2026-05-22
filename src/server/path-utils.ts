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
