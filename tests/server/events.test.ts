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
