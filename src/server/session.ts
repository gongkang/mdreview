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
