#!/usr/bin/env node
import { cp, mkdir, rm, writeFile } from "node:fs/promises";
import { constants } from "node:fs";
import { access, chmod } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const nativeDir = path.join(root, "native");
const appDir = path.join(nativeDir, "dist", "mdreview.app");
const contentsDir = path.join(appDir, "Contents");
const macOSDir = path.join(contentsDir, "MacOS");
const resourcesDir = path.join(contentsDir, "Resources");
const rendererSourceDir = path.join(root, "dist", "client");
const rendererTargetDir = path.join(resourcesDir, "renderer");
const infoPlistPath = path.join(nativeDir, "Info.plist");

async function assertExists(target, message) {
  try {
    await access(target, constants.R_OK);
  } catch {
    throw new Error(message);
  }
}

function swiftBinPath() {
  const env = {
    ...process.env,
    DEVELOPER_DIR: process.env.DEVELOPER_DIR ?? "/Applications/Xcode.app/Contents/Developer"
  };
  return execFileSync("xcrun", ["swift", "build", "--package-path", nativeDir, "--show-bin-path"], {
    cwd: root,
    env,
    encoding: "utf8"
  }).trim();
}

await assertExists(rendererSourceDir, "缺少前端构建产物：请先运行 npm run build:web");
await assertExists(infoPlistPath, "缺少 native/Info.plist");

const executableSource = path.join(swiftBinPath(), "mdreview-app");
await assertExists(executableSource, "缺少 native 可执行文件：请先运行 npm run build:native");

await rm(appDir, { recursive: true, force: true });
await mkdir(macOSDir, { recursive: true });
await mkdir(resourcesDir, { recursive: true });

await cp(infoPlistPath, path.join(contentsDir, "Info.plist"));
await writeFile(path.join(contentsDir, "PkgInfo"), "APPL????");
await cp(executableSource, path.join(macOSDir, "mdreview-app"));
await chmod(path.join(macOSDir, "mdreview-app"), 0o755);
await cp(rendererSourceDir, rendererTargetDir, { recursive: true });

console.log(`Created ${path.relative(root, appDir)}`);
