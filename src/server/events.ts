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
